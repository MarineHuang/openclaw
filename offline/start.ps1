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
Write-Host "   http://127.0.0.1:18789/#token=<your token>" -ForegroundColor Cyan
Write-Host ""
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

try {
    & "$PSScriptRoot\node-runtime\node.exe" "$PSScriptRoot\openclaw.mjs" gateway --allow-unconfigured --port 18789
} catch {
    Write-Host ""
    Write-Host " 启动失败: $_" -ForegroundColor Red
    Write-Host " 请检查端口 18789 是否被占用" -ForegroundColor Yellow
    Write-Host ""
    Read-Host " 按回车键退出"
}
