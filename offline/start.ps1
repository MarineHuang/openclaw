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
    [switch]$Backup,
    [string]$Restore,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PID_FILE = ".openclaw\gateway.pid"
$LOG_FILE = ".openclaw\logs\gateway.log"
$BACKUP_DIR = "backups"

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
  -Backup            备份用户数据 (.openclaw 目录)
  -Restore <路径>    从备份文件恢复用户数据
  -Force             强制执行 (如覆盖已有数据)
  -Help              显示此帮助信息

示例:
  .\start.ps1                           # 默认端口 18789，仅本机访问
  .\start.ps1 -Port 8080                # 使用端口 8080
  .\start.ps1 -Public                   # 公网访问模式
  .\start.ps1 -Bind lan -Port 8080      # 局域网访问，端口 8080
  .\start.ps1 -Daemon                   # 后台运行
  .\start.ps1 -Status                   # 查看状态
  .\start.ps1 -Stop                     # 停止服务
  .\start.ps1 -Backup                   # 备份数据
  .\start.ps1 -Restore backups\openclaw-data-xxx.tar.gz  # 恢复数据

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

# ── 备份用户数据 ──────────────────────────────────────────────────────
if ($Backup) {
    if (-not (Test-Path ".openclaw")) {
        Write-Host "错误: .openclaw 目录不存在，无数据可备份" -ForegroundColor Red
        Write-Host "请先启动一次服务以初始化数据目录"
        exit 1
    }

    # 检查目录是否为空
    $items = Get-ChildItem -Path ".openclaw" -ErrorAction SilentlyContinue
    if ($items.Count -eq 0) {
        Write-Host "错误: .openclaw 目录为空，无数据可备份" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Force $BACKUP_DIR | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = "$BACKUP_DIR\openclaw-data-$timestamp.tar.gz"

    Write-Host "正在备份用户数据..."
    Write-Host "源目录: .openclaw\"

    # 使用 PowerShell 的 Compress-Archive 创建 zip，然后用 tar（如果可用）
    # Windows 10+ 有 tar 命令
    try {
        # 排除日志和临时文件
        $excludePatterns = @("*.log", "*.tmp", "gateway.pid")
        $tempDir = "$env:TEMP\openclaw-backup-$timestamp"
        New-Item -ItemType Directory -Force $tempDir | Out-Null

        # 复制文件，排除不需要的
        Get-ChildItem -Path ".openclaw" -Recurse | Where-Object {
            $exclude = $false
            foreach ($pattern in $excludePatterns) {
                if ($_.Name -like $pattern) { $exclude = $true; break }
            }
            -not $exclude
        } | ForEach-Object {
            $targetPath = $_.FullName.Replace("$PSScriptRoot\.openclaw", $tempDir)
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Force $targetPath -ErrorAction SilentlyContinue | Out-Null
            } else {
                $targetDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Force $targetDir | Out-Null
                }
                Copy-Item $_.FullName $targetPath -Force
            }
        }

        # 使用 tar 打包（Windows 10+ 内置）
        & tar -czf $backupFile -C $tempDir "..\.openclaw" 2>$null
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

        if (Test-Path $backupFile) {
            $backupSize = (Get-Item $backupFile).Length / 1MB
            Write-Host ""
            Write-Host "备份完成!" -ForegroundColor Green
            Write-Host "备份文件: $backupFile"
            Write-Host "文件大小: $([math]::Round($backupSize, 2)) MB"
            Write-Host ""
            Write-Host "恢复命令: .\start.ps1 -Restore $backupFile"
            exit 0
        } else {
            Write-Host "错误: 备份失败" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "错误: 备份失败 - $_" -ForegroundColor Red
        exit 1
    }
}

# ── 恢复用户数据 ──────────────────────────────────────────────────────
if ($Restore -ne "") {
    $restoreFile = $Restore

    # 支持相对路径
    if (-not [System.IO.Path]::IsPathRooted($restoreFile)) {
        $restoreFile = "$PSScriptRoot\$restoreFile"
    }

    if (-not (Test-Path $restoreFile)) {
        Write-Host "错误: 备份文件不存在: $restoreFile" -ForegroundColor Red
        exit 1
    }

    # 检查是否已有 .openclaw 目录
    if (Test-Path ".openclaw") {
        if (-not $Force) {
            Write-Host "警告: 当前目录已存在 .openclaw 目录" -ForegroundColor Yellow
            Write-Host "恢复操作将覆盖现有数据!"
            Write-Host ""
            Write-Host "请使用 -Force 参数确认覆盖:"
            Write-Host "  .\start.ps1 -Restore `"$Restore`" -Force"
            Write-Host ""
            Write-Host "或先手动备份现有数据:"
            Write-Host "  .\start.ps1 -Backup"
            exit 1
        }
        Write-Host "警告: 将覆盖现有 .openclaw 目录"
        Remove-Item -Recurse -Force ".openclaw" -ErrorAction SilentlyContinue
    }

    Write-Host "正在从备份恢复用户数据..."
    Write-Host "备份文件: $restoreFile"

    try {
        # 使用 tar 解压（Windows 10+ 内置）
        & tar -xzf $restoreFile -C $PSScriptRoot 2>$null

        if (Test-Path ".openclaw") {
            Write-Host ""
            Write-Host "恢复完成!" -ForegroundColor Green
            Write-Host "数据目录: .openclaw\"
            Write-Host ""
            Write-Host "下一步: 启动服务"
            Write-Host "  .\start.ps1 -Daemon"
            exit 0
        } else {
            Write-Host "错误: 恢复失败，备份文件可能损坏" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "错误: 恢复失败 - $_" -ForegroundColor Red
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

    # 首次启动时安装预置的微信插件
    if ((Test-Path "plugins\openclaw-weixin") -and -not (Test-Path ".openclaw\extensions\openclaw-weixin")) {
        New-Item -ItemType Directory -Force ".openclaw\extensions" | Out-Null
        Copy-Item -Recurse "plugins\openclaw-weixin" ".openclaw\extensions\openclaw-weixin"
        Write-Host " 已安装微信插件"
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

# 首次启动时安装预置的微信插件
if ((Test-Path "plugins\openclaw-weixin") -and -not (Test-Path ".openclaw\extensions\openclaw-weixin")) {
    New-Item -ItemType Directory -Force ".openclaw\extensions" | Out-Null
    Copy-Item -Recurse "plugins\openclaw-weixin" ".openclaw\extensions\openclaw-weixin"
    Write-Host " 已安装微信插件，请在 Dashboard 中配置微信" -ForegroundColor Green
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