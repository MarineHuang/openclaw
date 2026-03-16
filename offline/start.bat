@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

REM ── 默认配置 ──────────────────────────────────────────────────────
set DEFAULT_PORT=18789
set DEFAULT_BIND=loopback
set PORT=%DEFAULT_PORT%
set BIND=%DEFAULT_BIND%
set ALLOW_HTTP=0

REM ── 解析参数 ──────────────────────────────────────────────────────
:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--port" (set PORT=%~2& shift & shift & goto :parse_args)
if /i "%~1"=="--bind" (set BIND=%~2& shift & shift & goto :parse_args)
if /i "%~1"=="--public" (set BIND=lan& set ALLOW_HTTP=1& shift & goto :parse_args)
if /i "%~1"=="--allow-http" (set ALLOW_HTTP=1& shift & goto :parse_args)
echo Unknown option: %~1
echo Use --help to see available options.
exit /b 1

:show_help
echo.
echo OpenClaw Offline Startup Script
echo.
echo Usage:
echo   start.bat [options]
echo.
echo Options:
echo   --port ^<port^>      Listen port (default: 18789)
echo   --bind ^<address^>   Bind address: loopback, lan, tailnet, auto (default: loopback)
echo   --public           Public access mode (same as --bind lan --allow-http)
echo   --allow-http       Allow HTTP public access (disable device auth)
echo   -h, --help         Show this help message
echo.
echo Examples:
echo   start.bat                           Default port 18789, localhost only
echo   start.bat --port 8080               Use port 8080
echo   start.bat --public                  Public access mode
echo   start.bat --bind lan --port 8080    LAN access, port 8080
echo.
echo Note:
echo   --public and --allow-http reduce security, only for internal/testing.
echo   For production, use HTTPS reverse proxy.
echo.
exit /b 0

:done_args

echo ============================================
echo  OpenClaw Offline
echo ============================================
echo.
echo  Starting OpenClaw Gateway...
echo  Open in browser after startup:
echo.
echo    http://127.0.0.1:%PORT%/#token=(your token)
echo.
if not "%BIND%"=="loopback" echo  Bind address: %BIND%
if "%ALLOW_HTTP%"=="1" echo   Warning: HTTP public access enabled (reduced security)
echo  Press Ctrl+C to stop.
echo  See README.md for instructions.
echo ============================================
echo.

set "OPENCLAW_STATE_DIR=%~dp0.openclaw"
set "OPENCLAW_HOME=%~dp0"
set OPENCLAW_DEFAULT_LOCALE=zh-CN
set NODE_ENV=production

if not exist ".openclaw\openclaw.json" (
    if not exist ".openclaw" mkdir ".openclaw"
    copy /Y "openclaw-providers.json" ".openclaw\providers.json" >nul
    copy /Y "openclaw-main.json"      ".openclaw\openclaw.json"  >nul
    echo  Default config initialized. Open Dashboard to select a provider and enter your API Key.
    echo.
)

if exist "plugins\openclaw-qqbot" if not exist ".openclaw\extensions\openclaw-qqbot" (
    if not exist ".openclaw\extensions" mkdir ".openclaw\extensions"
    xcopy /E /I /Q "plugins\openclaw-qqbot" ".openclaw\extensions\openclaw-qqbot" >nul
    echo  QQ Bot plugin installed. Configure QQ channel in Dashboard.
    echo.
)

REM 应用公网访问配置
if "%ALLOW_HTTP%"=="1" (
    if exist ".openclaw\openclaw.json" (
        echo  Enabling HTTP public access configuration...
        node-runtime\node.exe -e "const fs=require('fs');const cfg=JSON.parse(fs.readFileSync('.openclaw/openclaw.json','utf8'));cfg.gateway=cfg.gateway||{};cfg.gateway.controlUi=cfg.gateway.controlUi||{};cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true;cfg.gateway.controlUi.dangerouslyDisableDeviceAuth=true;fs.writeFileSync('.openclaw/openclaw.json',JSON.stringify(cfg,null,2));" 2>nul
        if !ERRORLEVEL! equ 0 (
            echo  HTTP public access enabled.
            echo.
        )
    )
)

node-runtime\node.exe openclaw.mjs gateway --allow-unconfigured --port %PORT% --bind %BIND%

if %ERRORLEVEL% neq 0 (
    echo.
    echo  Startup failed. Error code: %ERRORLEVEL%
    echo  Check if port %PORT% is already in use.
    echo.
    pause
)