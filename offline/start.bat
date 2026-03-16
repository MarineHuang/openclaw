@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

REM ── 默认配置 ──────────────────────────────────────────────────────
set DEFAULT_PORT=18789
set DEFAULT_BIND=loopback
set PORT=%DEFAULT_PORT%
set BIND=%DEFAULT_BIND%
set ALLOW_HTTP=0
set DAEMON_MODE=0
set ACTION=
set PID_FILE=.openclaw\gateway.pid
set LOG_FILE=.openclaw\logs\gateway.log

REM ── 解析参数 ──────────────────────────────────────────────────────
:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--port" (
    if "%~2"=="" goto :missing_port_arg
    echo %~2 | findstr /r "^--" >nul && goto :missing_port_arg
    set PORT=%~2& shift & shift & goto :parse_args
)
if /i "%~1"=="--bind" (
    if "%~2"=="" goto :missing_bind_arg
    echo %~2 | findstr /r "^--" >nul && goto :missing_bind_arg
    set BIND=%~2& shift & shift & goto :parse_args
)
if /i "%~1"=="--public" (set BIND=lan& set ALLOW_HTTP=1& shift & goto :parse_args)
if /i "%~1"=="--allow-http" (set ALLOW_HTTP=1& shift & goto :parse_args)
if /i "%~1"=="-d" (set DAEMON_MODE=1& shift & goto :parse_args)
if /i "%~1"=="--daemon" (set DAEMON_MODE=1& shift & goto :parse_args)
if /i "%~1"=="--stop" (set ACTION=stop& shift & goto :parse_args)
if /i "%~1"=="--status" (set ACTION=status& shift & goto :parse_args)
echo Unknown option: %~1
echo Use --help to see available options.
exit /b 1

:missing_port_arg
echo Error: --port requires a port number.
echo Use --help for usage information.
exit /b 1

:missing_bind_arg
echo Error: --bind requires an address.
echo Use --help for usage information.
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
echo   -d, --daemon       Run in background (daemon mode)
echo   --stop             Stop the background service
echo   --status           Show service status
echo   -h, --help         Show this help message
echo.
echo Examples:
echo   start.bat                           Default port 18789, localhost only
echo   start.bat --port 8080               Use port 8080
echo   start.bat --public                  Public access mode
echo   start.bat --bind lan --port 8080    LAN access, port 8080
echo   start.bat --daemon                  Run in background
echo   start.bat --status                  Show status
echo   start.bat --stop                    Stop service
echo.
echo Note:
echo   --public and --allow-http reduce security, only for internal/testing.
echo   For production, use HTTPS reverse proxy.
echo.
exit /b 0

:done_args

REM ── 处理 status 命令 ──────────────────────────────────────────────────────
if "%ACTION%"=="status" goto :check_status

REM ── 处理 stop 命令 ──────────────────────────────────────────────────────
if "%ACTION%"=="stop" goto :stop_service

REM ── 检查是否后台模式 ──────────────────────────────────────────────────────
if "%DAEMON_MODE%"=="1" goto :daemon_start

REM ── 检查服务状态 ──────────────────────────────────────────────────────
:check_status
if exist "%PID_FILE%" (
    set /p PID=<%PID_FILE%
    tasklist /FI "PID eq !PID!" 2>nul | findstr /I "node.exe" >nul
    if !ERRORLEVEL! equ 0 (
        echo Service status: Running (PID: !PID!)
        echo Log file: %LOG_FILE%
        echo.
        echo Recent logs:
        if exist "%LOG_FILE%" (
            type "%LOG_FILE%" | more +0 2>nul | findstr /n "^" | findstr "^[1-5]:"
        ) else (
            echo   ^(Log file does not exist^)
        )
    ) else (
        echo Service status: Stopped (PID file exists but process not running)
        del /f "%PID_FILE%" 2>nul
    )
) else (
    echo Service status: Not running
)
exit /b 0

REM ── 停止服务 ──────────────────────────────────────────────────────
:stop_service
if exist "%PID_FILE%" (
    set /p PID=<%PID_FILE%
    tasklist /FI "PID eq !PID!" 2>nul | findstr /I "node.exe" >nul
    if !ERRORLEVEL! equ 0 (
        echo Stopping OpenClaw Gateway (PID: !PID!)...
        taskkill /PID !PID! /F >nul 2>&1
        timeout /t 2 >nul
        del /f "%PID_FILE%" 2>nul
        echo Service stopped.
    ) else (
        echo Service not running (cleaning stale PID file).
        del /f "%PID_FILE%" 2>nul
    )
) else (
    echo Service not running (no PID file).
)
exit /b 0

REM ── 后台模式启动 ──────────────────────────────────────────────────────
:daemon_start

REM 检查是否已在运行
if exist "%PID_FILE%" (
    set /p EXIST_PID=<%PID_FILE%
    tasklist /FI "PID eq !EXIST_PID!" 2>nul | findstr /I "node.exe" >nul
    if !ERRORLEVEL! equ 0 (
        echo Service already running (PID: !EXIST_PID!^)
        echo Use start.bat --status to check status
        echo Use start.bat --stop to stop service
        exit /b 0
    )
    del /f "%PID_FILE%" 2>nul
)

REM 创建日志目录
if not exist ".openclaw\logs" mkdir ".openclaw\logs"

echo ============================================
echo  OpenClaw Offline (Daemon Mode)
echo ============================================
echo.
echo  Starting OpenClaw Gateway...
echo  Open in browser after startup:
echo.
echo    http://127.0.0.1:%PORT%/#token=(your token)
echo.
if not "%BIND%"=="loopback" echo  Bind address: %BIND%
if "%ALLOW_HTTP%"=="1" echo   Warning: HTTP public access enabled (reduced security)
echo  Log file: %LOG_FILE%
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
    echo  Default config initialized.
)

if exist "plugins\openclaw-qqbot" if not exist ".openclaw\extensions\openclaw-qqbot" (
    if not exist ".openclaw\extensions" mkdir ".openclaw\extensions"
    xcopy /E /I /Q "plugins\openclaw-qqbot" ".openclaw\extensions\openclaw-qqbot" >nul
    echo  QQ Bot plugin installed.
)

REM 应用公网访问配置
if "%ALLOW_HTTP%"=="1" (
    if exist ".openclaw\openclaw.json" (
        node-runtime\node.exe -e "const fs=require('fs');const cfg=JSON.parse(fs.readFileSync('.openclaw/openclaw.json','utf8'));cfg.gateway=cfg.gateway||{};cfg.gateway.controlUi=cfg.gateway.controlUi||{};cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true;cfg.gateway.controlUi.dangerouslyDisableDeviceAuth=true;fs.writeFileSync('.openclaw/openclaw.json',JSON.stringify(cfg,null,2));" 2>nul
        if !ERRORLEVEL! equ 0 (
            echo  HTTP public access enabled.
        )
    )
)

REM 使用 start /b 后台运行，输出重定向到日志文件
start /b "" node-runtime\node.exe openclaw.mjs gateway --allow-unconfigured --port %PORT% --bind %BIND% >> "%LOG_FILE%" 2>&1

REM 等待进程启动并获取 PID
timeout /t 2 >nul
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq node.exe" /FO LIST ^| findstr "PID:"') do (
    set NODE_PID=%%a
)
if defined NODE_PID (
    echo !NODE_PID! > "%PID_FILE%"
    echo Service started (PID: !NODE_PID!^)
    echo.
    echo Commands:
    echo   View logs: type %LOG_FILE%
    echo   Check status: start.bat --status
    echo   Stop service: start.bat --stop
) else (
    echo Startup failed. Check log: %LOG_FILE%
    exit /b 1
)
exit /b 0

REM ── 前台模式启动 ──────────────────────────────────────────────────────
:foreground_start

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