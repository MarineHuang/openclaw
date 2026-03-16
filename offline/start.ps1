# OpenClaw 离线版 启动脚本 (PowerShell)
param(
    [int]$Port = 18789,
    [ValidateSet("loopback", "lan", "tailnet", "auto")]
    [string]$Bind = "loopback",
    [switch]$Public,
    [switch]$AllowHttp,
    [switch]$Daemon,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PID_FILE = ".openclaw\gateway.pid"
$LOG_FILE = ".openclaw\logs\gateway.log"

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
  -Daemon            后台运行模式
  -Stop              停止后台运行的服务
  -Status            查看服务状态
  -Help              显示此帮助信息

示例:
  .\start.ps1                           # 默认端口 18789，仅本机访问
  .\start.ps1 -Port 8080                # 使用端口 8080
  .\start.ps1 -Public                   # 公网访问模式
  .\start.ps1 -Bind lan -Port 8080      # 局域网访问，端口 8080
  .\start.ps1 -Daemon                   # 后台运行
  .\start.ps1 -Status                   # 查看状态
  .\start.ps1 -Stop                     # 停止服务

注意:
  -Public 和 -AllowHttp 选项会降低安全性，仅适合内网/测试环境。
  生产环境请使用 HTTPS 反向代理。

"@
    exit 0
}

# ── 检查服务状态 ──────────────────────────────────────────────────────
if ($Status) {
    if (Test-Path $PID_FILE) {
        $savedPid = Get-Content $PID_FILE
        $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "服务状态: 运行中 (PID: $savedPid)"
            Write-Host "日志文件: $LOG_FILE"
            Write-Host ""
            Write-Host "最近的日志:"
            if (Test-Path $LOG_FILE) {
                Get-Content $LOG_FILE -Tail 5
            } else {
                Write-Host "  (日志文件不存在)"
            }
            exit 0
        } else {
            Write-Host "服务状态: 已停止 (PID 文件存在但进程未运行)"
            Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
            exit 1
        }
    } else {
        Write-Host "服务状态: 未运行"
        exit 1
    }
}

# ── 停止服务 ──────────────────────────────────────────────────────
if ($Stop) {
    if (Test-Path $PID_FILE) {
        $savedPid = Get-Content $PID_FILE
        $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "正在停止 OpenClaw Gateway (PID: $savedPid)..."
            Stop-Process -Id $savedPid -Force
            Start-Sleep -Seconds 2
            Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
            Write-Host "服务已停止"
            exit 0
        } else {
            Write-Host "服务未运行 (PID 文件过期，已清理)"
            Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
            exit 1
        }
    } else {
        Write-Host "服务未运行 (无 PID 文件)"
        exit 1
    }
}

# 处理 -Public 参数
if ($Public) {
    $Bind = "lan"
    $AllowHttp = $true
}

# ── 后台运行模式 ──────────────────────────────────────────────────────
if ($Daemon) {
    # 检查是否已在运行
    if (Test-Path $PID_FILE) {
        $existPid = Get-Content $PID_FILE
        $existProcess = Get-Process -Id $existPid -ErrorAction SilentlyContinue
        if ($existProcess) {
            Write-Host "服务已在运行中 (PID: $existPid)"
            Write-Host "使用 .\start.ps1 -Status 查看状态"
            Write-Host "使用 .\start.ps1 -Stop 停止服务"
            exit 0
        }
        Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
    }

    # 创建日志目录
    $logDir = Split-Path $LOG_FILE -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force $logDir | Out-Null
    }

    Write-Host "============================================"
    Write-Host " OpenClaw 离线版 (后台模式)"
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
    Write-Host " 日志文件: $LOG_FILE"
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
        Write-Host " 已初始化默认配置"
    }

    # 首次启动时安装预置的 QQ Bot 插件
    if ((Test-Path "plugins\openclaw-qqbot") -and -not (Test-Path ".openclaw\extensions\openclaw-qqbot")) {
        New-Item -ItemType Directory -Force ".openclaw\extensions" | Out-Null
        Copy-Item -Recurse "plugins\openclaw-qqbot" ".openclaw\extensions\openclaw-qqbot"
        Write-Host " 已安装 QQ Bot 插件"
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
                Write-Host " 已启用公网 HTTP 访问配置"
            } catch {
                # 忽略配置错误
            }
        }
    }

    # 后台启动
    $process = Start-Process -FilePath "$PSScriptRoot\node-runtime\node.exe" `
        -ArgumentList "openclaw.mjs", "gateway", "--allow-unconfigured", "--port", $Port, "--bind", $Bind `
        -WindowStyle Hidden -RedirectStandardOutput "$PSScriptRoot\$LOG_FILE" -RedirectStandardError "$PSScriptRoot\$LOG_FILE" -PassThru

    if ($process) {
        $process.Id | Set-Content $PID_FILE
        Write-Host "服务已启动 (PID: $($process.Id))"
        Write-Host ""
        Write-Host "命令:"
        Write-Host "  查看日志: Get-Content $LOG_FILE -Tail 20"
        Write-Host "  查看状态: .\start.ps1 -Status"
        Write-Host "  停止服务: .\start.ps1 -Stop"
    } else {
        Write-Host "启动失败，请查看日志: $LOG_FILE" -ForegroundColor Red
        exit 1
    }
    exit 0
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