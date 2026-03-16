# OpenClaw 离线版 启动脚本 (PowerShell)
param(
    [int]$Port = 18789,
    [ValidateSet("loopback", "lan", "tailnet", "auto")]
    [string]$Bind = "loopback",
    [switch]$Public,
    [switch]$AllowHttp,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── 帮助信息 ──────────────────────────────────────────────────────
if ($Help) {
    Write-Host @"

OpenClaw 离线版启动脚本

用法:
  .\start.ps1 [选项]

选项:
  -Port <端口>       监听端口 (默认: 18789)
  -Bind <地址>       绑定地址: loopback, lan, tailnet, auto (默认: loopback)
  -Public            公网访问模式 (等同于 -Bind lan -AllowHttp)
  -AllowHttp         允许 HTTP 公网访问 (禁用设备身份校验)
  -Help              显示此帮助信息

示例:
  .\start.ps1                           # 默认端口 18789，仅本机访问
  .\start.ps1 -Port 8080                # 使用端口 8080
  .\start.ps1 -Public                   # 公网访问模式
  .\start.ps1 -Bind lan -Port 8080      # 局域网访问，端口 8080

注意:
  -Public 和 -AllowHttp 选项会降低安全性，仅适合内网/测试环境。
  生产环境请使用 HTTPS 反向代理。

"@
    exit 0
}

# 处理 -Public 参数
if ($Public) {
    $Bind = "lan"
    $AllowHttp = $true
}

Write-Host "============================================"
Write-Host " OpenClaw 离线版"
Write-Host "============================================"
Write-Host ""
Write-Host " 正在启动 OpenClaw Gateway..."
Write-Host " 启动后请在浏览器中打开:"
Write-Host ""
Write-Host "   http://127.0.0.1:${Port}/#token=<your token>" -ForegroundColor Cyan
Write-Host ""
if ($Bind -ne "loopback") {
    Write-Host " 绑定地址: $Bind"
}
if ($AllowHttp) {
    Write-Host " ⚠️  HTTP 公网访问已启用 (安全性降低)" -ForegroundColor Yellow
}
Write-Host " 按 Ctrl+C 可停止服务"
Write-Host "============================================"
Write-Host ""

$env:OPENCLAW_STATE_DIR = "$PSScriptRoot\.openclaw"
$env:OPENCLAW_HOME = "$PSScriptRoot"
$env:OPENCLAW_DEFAULT_LOCALE = "zh-CN"
$env:NODE_ENV = "production"

# 首次启动时初始化默认配置
if (-not (Test-Path ".openclaw\openclaw.json")) {
    New-Item -ItemType Directory -Force ".openclaw" | Out-Null
    Copy-Item "openclaw-providers.json" ".openclaw\providers.json"
    Copy-Item "openclaw-main.json"      ".openclaw\openclaw.json"
    Write-Host " 已初始化默认配置，请在 Dashboard 中选择提供商并填写 API Key" -ForegroundColor Green
    Write-Host ""
}

# 首次启动时安装预置的 QQ Bot 插件
if ((Test-Path "plugins\openclaw-qqbot") -and -not (Test-Path ".openclaw\extensions\openclaw-qqbot")) {
    New-Item -ItemType Directory -Force ".openclaw\extensions" | Out-Null
    Copy-Item -Recurse "plugins\openclaw-qqbot" ".openclaw\extensions\openclaw-qqbot"
    Write-Host " 已安装 QQ Bot 插件，请在 Dashboard 中配置 QQ 频道" -ForegroundColor Green
    Write-Host ""
}

# 应用公网访问配置
if ($AllowHttp) {
    $configFile = ".openclaw\openclaw.json"
    if (Test-Path $configFile) {
        try {
            $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
            if (-not $cfg.gateway) { $cfg | Add-Member -MemberType NoteProperty -Name "gateway" -Value @{} -Force }
            if (-not $cfg.gateway.controlUi) {
                $cfg.gateway | Add-Member -MemberType NoteProperty -Name "controlUi" -Value @{} -Force
            }
            $cfg.gateway.controlUi | Add-Member -MemberType NoteProperty -Name "dangerouslyAllowHostHeaderOriginFallback" -Value $true -Force
            $cfg.gateway.controlUi | Add-Member -MemberType NoteProperty -Name "dangerouslyDisableDeviceAuth" -Value $true -Force
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
            Write-Host " 已启用公网 HTTP 访问配置" -ForegroundColor Green
            Write-Host ""
        } catch {
            Write-Host " ⚠️  无法自动配置公网访问，请手动编辑 .openclaw\openclaw.json" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

try {
    & "$PSScriptRoot\node-runtime\node.exe" "$PSScriptRoot\openclaw.mjs" gateway --allow-unconfigured --port $Port --bind $Bind
} catch {
    Write-Host ""
    Write-Host " 启动失败: $_" -ForegroundColor Red
    Write-Host " 请检查端口 $Port 是否被占用" -ForegroundColor Yellow
    Write-Host ""
    Read-Host " 按回车键退出"
}