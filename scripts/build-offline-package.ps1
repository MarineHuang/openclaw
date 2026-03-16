#Requires -Version 5.1
<#
.SYNOPSIS
    Build an all-in-one offline package for OpenClaw (Windows).

.DESCRIPTION
    Run this on a machine with network access, pnpm, and Node.js installed.
    The resulting archive can be transferred to an air-gapped machine —
    no Node.js, npm, or internet required to run.

.PARAMETER Target
    Target platform: win-x64, linux-x64, linux-arm64, darwin-x64, darwin-arm64.
    Default: auto-detect host.

.PARAMETER NodeVersion
    Node.js version to bundle. Default: 22.14.0

.PARAMETER SkipBuild
    Skip pnpm install / build steps (use existing dist/).

.PARAMETER OutputDir
    Directory for the final archive. Default: ./offline-dist

.EXAMPLE
    .\scripts\build-offline-package.ps1
    .\scripts\build-offline-package.ps1 -Target win-x64 -SkipBuild
#>
param(
    [string]$Target = "",
    [string]$NodeVersion = "22.14.0",
    [switch]$SkipBuild,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

if (-not $OutputDir) {
    $OutputDir = Join-Path $ProjectRoot "offline-dist"
}

# ── Auto-detect target platform ──────────────────────────────────
if (-not $Target) {
    $osInfo = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    if ($env:OS -eq "Windows_NT" -or $osInfo -match "Windows") {
        $osPart = "win"
    } elseif ($IsLinux) {
        $osPart = "linux"
    } elseif ($IsMacOS) {
        $osPart = "darwin"
    } else {
        Write-Error "Cannot auto-detect OS. Use -Target parameter."
        exit 1
    }

    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch) {
        "X64"   { $archPart = "x64" }
        "Arm64" { $archPart = "arm64" }
        default { Write-Error "Cannot auto-detect arch ($arch). Use -Target parameter."; exit 1 }
    }

    $Target = "$osPart-$archPart"
}

# ── Validate target ──────────────────────────────────────────────
$validTargets = @("win-x64", "linux-x64", "linux-arm64", "darwin-x64", "darwin-arm64")
if ($Target -notin $validTargets) {
    Write-Error "Unsupported target: $Target. Valid: $($validTargets -join ', ')"
    exit 1
}

$targetParts = $Target -split "-"
$targetOS = $targetParts[0]
$targetArch = $targetParts[1]

# ── Derive Node.js download URL ──────────────────────────────────
$nodeBaseUrl = "https://nodejs.org/dist/v$NodeVersion"
switch ($Target) {
    "win-x64"       { $nodeArchive = "node-v$NodeVersion-win-x64.zip" }
    "linux-x64"     { $nodeArchive = "node-v$NodeVersion-linux-x64.tar.xz" }
    "linux-arm64"   { $nodeArchive = "node-v$NodeVersion-linux-arm64.tar.xz" }
    "darwin-x64"    { $nodeArchive = "node-v$NodeVersion-darwin-x64.tar.gz" }
    "darwin-arm64"  { $nodeArchive = "node-v$NodeVersion-darwin-arm64.tar.gz" }
}
$nodeUrl = "$nodeBaseUrl/$nodeArchive"

# Read version from package.json
$packageJson = Get-Content (Join-Path $ProjectRoot "package.json") -Raw | ConvertFrom-Json
$version = $packageJson.version
$packageName = "openclaw-offline-$version-$Target"

Write-Host "============================================"
Write-Host " OpenClaw Offline Package Builder"
Write-Host "============================================"
Write-Host " Version:      $version"
Write-Host " Target:       $Target"
Write-Host " Node.js:      v$NodeVersion"
Write-Host " Output:       $OutputDir\$packageName"
Write-Host "============================================"
Write-Host ""

# ── Step 1: Build project ────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Host "[1/5] Installing dependencies..."
    Push-Location $ProjectRoot
    try {
        & pnpm install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }

        Write-Host ""
        Write-Host "[2/5] Building project..."
        & pnpm build
        if ($LASTEXITCODE -ne 0) { throw "pnpm build failed" }

        Write-Host ""
        Write-Host "[3/5] Building Dashboard UI..."
        & pnpm ui:build
        if ($LASTEXITCODE -ne 0) { throw "pnpm ui:build failed" }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[1-3/5] Skipping build (-SkipBuild)"
}

# ── Step 2: Download Node.js ─────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Downloading Node.js v$NodeVersion for $Target..."

$cacheDir = Join-Path $ProjectRoot ".offline-cache"
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }

$nodeCached = Join-Path $cacheDir $nodeArchive
if (Test-Path $nodeCached) {
    Write-Host "  Using cached: $nodeCached"
} else {
    Write-Host "  Downloading: $nodeUrl"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeCached -UseBasicParsing
    $ProgressPreference = 'Continue'
}

# ── Step 3: Assemble staging directory ───────────────────────────
Write-Host ""
Write-Host "[5/5] Assembling offline package..."

$staging = Join-Path $OutputDir ".staging-$Target"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

# Extract Node.js binary into node-runtime/
$nodeExtractTmp = Join-Path $staging ".node-extract"
New-Item -ItemType Directory -Path $nodeExtractTmp -Force | Out-Null

if ($targetOS -eq "win") {
    Expand-Archive -Path $nodeCached -DestinationPath $nodeExtractTmp -Force
    $nodeRuntimeDir = Join-Path $staging "node-runtime"
    New-Item -ItemType Directory -Path $nodeRuntimeDir -Force | Out-Null
    $nodeExe = Get-ChildItem -Path $nodeExtractTmp -Recurse -Filter "node.exe" | Select-Object -First 1
    Copy-Item $nodeExe.FullName (Join-Path $nodeRuntimeDir "node.exe")
} else {
    # For non-Windows targets built on Windows, use tar (available on Win10+)
    & tar -xf $nodeCached -C $nodeExtractTmp
    $nodeRuntimeBin = Join-Path $staging "node-runtime" "bin"
    New-Item -ItemType Directory -Path $nodeRuntimeBin -Force | Out-Null
    $nodeBin = Get-ChildItem -Path $nodeExtractTmp -Recurse -Filter "node" -File | Select-Object -First 1
    Copy-Item $nodeBin.FullName (Join-Path $nodeRuntimeBin "node")
}
Remove-Item -Recurse -Force $nodeExtractTmp

# Copy project files
Copy-Item (Join-Path $ProjectRoot "openclaw.mjs") $staging
Copy-Item (Join-Path $ProjectRoot "package.json") $staging

# dist/
$distDir = Join-Path $ProjectRoot "dist"
if (-not (Test-Path $distDir)) {
    Write-Error "dist/ not found. Run build first (remove -SkipBuild)."
    exit 1
}
Copy-Item -Recurse $distDir (Join-Path $staging "dist")

# node_modules/ — production dependencies
Write-Host "  Collecting production dependencies..."
$prodTmp = Join-Path $OutputDir ".prod-deps-$Target"
if (Test-Path $prodTmp) { Remove-Item -Recurse -Force $prodTmp }
New-Item -ItemType Directory -Path $prodTmp -Force | Out-Null

$deploySuccess = $false
Push-Location $ProjectRoot
try {
    & pnpm deploy --prod --no-optional $prodTmp 2>$null
    if ($LASTEXITCODE -eq 0) { $deploySuccess = $true }
} catch { }
Pop-Location

if ($deploySuccess -and (Test-Path (Join-Path $prodTmp "node_modules"))) {
    Copy-Item -Recurse (Join-Path $prodTmp "node_modules") (Join-Path $staging "node_modules")
    Remove-Item -Recurse -Force $prodTmp
} else {
    Write-Host "  pnpm deploy failed, falling back to copy..."
    Copy-Item -Recurse (Join-Path $ProjectRoot "node_modules") (Join-Path $staging "node_modules")
    if (Test-Path $prodTmp) { Remove-Item -Recurse -Force $prodTmp }
}

# Additional project directories
foreach ($dir in @("extensions", "skills", "docs", "assets")) {
    $srcDir = Join-Path $ProjectRoot $dir
    if (Test-Path $srcDir) {
        Copy-Item -Recurse $srcDir (Join-Path $staging $dir)
    }
}

# ── Generate startup scripts ─────────────────────────────────────

# start.bat (Windows)
$startBat = @'
@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo ============================================
echo  OpenClaw 离线版
echo ============================================
echo.
echo  正在启动 OpenClaw Gateway...
echo  启动后请在浏览器中打开:
echo.
echo    http://127.0.0.1:18789
echo.
echo  按 Ctrl+C 可停止服务
echo ============================================
echo.

set NODE_ENV=production
node-runtime\node.exe openclaw.mjs gateway --allow-unconfigured --port 18789

if %ERRORLEVEL% neq 0 (
    echo.
    echo  启动失败，错误代码: %ERRORLEVEL%
    echo  请检查端口 18789 是否被占用
    echo.
    pause
)
'@
[System.IO.File]::WriteAllText((Join-Path $staging "start.bat"), $startBat, [System.Text.Encoding]::UTF8)

# start.ps1 (Windows PowerShell)
$startPs1 = @'
# OpenClaw 离线版 启动脚本 (PowerShell)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================"
Write-Host " OpenClaw 离线版"
Write-Host "============================================"
Write-Host ""
Write-Host " 正在启动 OpenClaw Gateway..."
Write-Host " 启动后请在浏览器中打开:"
Write-Host ""
Write-Host "   http://127.0.0.1:18789" -ForegroundColor Cyan
Write-Host ""
Write-Host " 按 Ctrl+C 可停止服务"
Write-Host "============================================"
Write-Host ""

$env:NODE_ENV = "production"

try {
    & "$PSScriptRoot\node-runtime\node.exe" "$PSScriptRoot\openclaw.mjs" gateway --allow-unconfigured --port 18789
} catch {
    Write-Host ""
    Write-Host " 启动失败: $_" -ForegroundColor Red
    Write-Host " 请检查端口 18789 是否被占用" -ForegroundColor Yellow
    Write-Host ""
    Read-Host " 按回车键退出"
}
'@
[System.IO.File]::WriteAllText((Join-Path $staging "start.ps1"), $startPs1, [System.Text.Encoding]::UTF8)

# start.sh (Linux/macOS)
$startSh = @'
#!/bin/bash
cd "$(dirname "$0")"

echo "============================================"
echo " OpenClaw 离线版"
echo "============================================"
echo ""
echo " 正在启动 OpenClaw Gateway..."
echo " 启动后请在浏览器中打开:"
echo ""
echo "   http://127.0.0.1:18789"
echo ""
echo " 按 Ctrl+C 可停止服务"
echo "============================================"
echo ""

export NODE_ENV=production
./node-runtime/bin/node openclaw.mjs gateway --allow-unconfigured --port 18789
'@
# Use LF line endings for shell script
$startSh = $startSh -replace "`r`n", "`n"
[System.IO.File]::WriteAllBytes((Join-Path $staging "start.sh"), [System.Text.Encoding]::UTF8.GetBytes($startSh))

# ── Generate 安装说明.md ──────────────────────────────────────────
$readme = @'
# OpenClaw 离线安装包 使用说明

## 快速开始

### Windows 用户

1. 将本压缩包解压到任意目录（如 `D:\openclaw`）
2. 双击 `start.bat` 或右键 `start.ps1` 选择"使用 PowerShell 运行"
3. 在浏览器中打开 http://127.0.0.1:18789

> 提示：如果 PowerShell 提示"无法加载文件...因为在此系统上禁止运行脚本"，
> 请以管理员身份打开 PowerShell 并执行：`Set-ExecutionPolicy RemoteSigned`

### Linux / macOS 用户

1. 解压压缩包：
   ```bash
   tar xzf openclaw-offline-*.tar.gz
   cd openclaw-offline-*
   ```
2. 运行启动脚本：
   ```bash
   chmod +x start.sh node-runtime/bin/node
   ./start.sh
   ```
3. 在浏览器中打开 http://127.0.0.1:18789

## 说明

- 本离线包已包含 Node.js 运行时和所有依赖，**无需安装任何软件**
- 默认监听端口为 **18789**，如需修改请编辑启动脚本中的 `--port` 参数
- 数据存储在用户主目录下的 `.openclaw` 文件夹中

## 常见问题

### 端口被占用

如果提示端口 18789 被占用，可以修改启动脚本中的端口号，例如改为 `--port 28789`。

### Linux 下提示权限不足

运行以下命令添加执行权限：
```bash
chmod +x start.sh node-runtime/bin/node
```

### macOS 提示无法验证开发者

首次运行时 macOS 可能提示"无法验证开发者"，请在 **系统设置 → 隐私与安全性** 中允许运行。

## 技术信息

- OpenClaw 版本：见 package.json 中的 version 字段
- Node.js 运行时：见 node-runtime/ 目录
- 项目主页：https://github.com/openclaw/openclaw
'@
[System.IO.File]::WriteAllText((Join-Path $staging "安装说明.md"), $readme, [System.Text.Encoding]::UTF8)

# ── Step 4: Create archive ───────────────────────────────────────
Write-Host ""
Write-Host "Creating archive..."

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

# Rename staging dir to final package name
$finalDir = Join-Path $OutputDir $packageName
if (Test-Path $finalDir) { Remove-Item -Recurse -Force $finalDir }
Rename-Item $staging $packageName

# Create .zip (native on Windows)
$zipFile = Join-Path $OutputDir "$packageName.zip"
if (Test-Path $zipFile) { Remove-Item -Force $zipFile }
Compress-Archive -Path $finalDir -DestinationPath $zipFile
Write-Host "  Created: $zipFile"

# Also create .tar.gz if tar is available (Win10+)
$tarFile = Join-Path $OutputDir "$packageName.tar.gz"
$tarAvailable = $false
try {
    & tar --version 2>$null | Out-Null
    $tarAvailable = ($LASTEXITCODE -eq 0)
} catch { }

if ($tarAvailable) {
    Push-Location $OutputDir
    & tar czf "$packageName.tar.gz" $packageName
    Pop-Location
    Write-Host "  Created: $tarFile"
}

# Clean up the uncompressed directory
Remove-Item -Recurse -Force $finalDir

# Print summary
$primaryArchive = if (Test-Path $zipFile) { $zipFile } else { $tarFile }
$archiveSize = (Get-Item $primaryArchive).Length
$sizeMB = [math]::Round($archiveSize / 1MB, 1)

Write-Host ""
Write-Host "============================================"
Write-Host " Build complete!"
Write-Host "============================================"
Write-Host " Archive:  $primaryArchive"
Write-Host " Size:     ${sizeMB} MB"
Write-Host ""
Write-Host " To use:"
Write-Host "   1. Copy the archive to the target machine"
Write-Host "   2. Extract the archive"
Write-Host "   3. Run: start.bat / start.ps1 (Windows) or ./start.sh (Linux/macOS)"
Write-Host "============================================"
