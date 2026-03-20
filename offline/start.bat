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
set RESTORE_PATH=
set FORCE_MODE=0
set PID_FILE=.openclaw\gateway.pid
set LOG_FILE=.openclaw\logs\gateway.log
set BACKUP_DIR=backups

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
if /i "%~1"=="--backup" (set ACTION=backup& shift & goto :parse_args)
if /i "%~1"=="--restore" (
    if "%~2"=="" set ACTION=restore& shift & goto :parse_args
    echo %~2 | findstr /r "^--" >nul && (set ACTION=restore& shift & goto :parse_args)
    set RESTORE_PATH=%~2& set ACTION=restore& shift & shift & goto :parse_args
)
if /i "%~1"=="--force" (set FORCE_MODE=1& shift & goto :parse_args)
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
echo   --backup           Backup user data (.openclaw directory)
echo   --restore ^<path^>   Restore user data from backup file
echo   --force            Force operation (e.g., overwrite existing data)
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
echo   start.bat --backup                  Backup data
echo   start.bat --restore backups\openclaw-data-xxx.tar.gz  Restore data
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

REM ── 处理 backup 命令 ──────────────────────────────────────────────────────
if "%ACTION%"=="backup" goto :backup_data

REM ── 处理 restore 命令 ──────────────────────────────────────────────────────
if "%ACTION%"=="restore" goto :restore_data

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

REM ── 备份用户数据 ──────────────────────────────────────────────────────
:backup_data
if not exist ".openclaw" (
    echo Error: .openclaw directory does not exist, no data to backup.
    echo Please start the service first to initialize the data directory.
    exit /b 1
)

REM 检查目录是否为空
dir /b ".openclaw" 2>nul | findstr "^" >nul
if errorlevel 1 (
    echo Error: .openclaw directory is empty, no data to backup.
    exit /b 1
)

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM 获取时间戳
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list 2^>nul') do set DATETIME=%%I
set TIMESTAMP=%DATETIME:~0,8%-%DATETIME:~8,6%
set BACKUP_FILE=%BACKUP_DIR%\openclaw-data-%TIMESTAMP%.tar.gz

echo Backing up user data...
echo Source directory: .openclaw\

REM 使用 tar 打包（Windows 10+ 内置）
tar --exclude=".openclaw\logs\*.log" --exclude=".openclaw\logs\*.log.*" --exclude=".openclaw\gateway.pid" --exclude=".openclaw\*.tmp" -czf "%BACKUP_FILE%" .openclaw\ 2>nul

if exist "%BACKUP_FILE%" (
    for %%A in ("%BACKUP_FILE%") do set BACKUP_SIZE=%%~zA
    echo.
    echo Backup complete!
    echo Backup file: %BACKUP_FILE%
    echo File size: !BACKUP_SIZE! bytes
    echo.
    echo Restore command: start.bat --restore %BACKUP_FILE%
    exit /b 0
) else (
    echo Error: Backup failed.
    exit /b 1
)

REM ── 恢复用户数据 ──────────────────────────────────────────────────────
:restore_data
if "%RESTORE_PATH%"=="" (
    echo Error: Please specify a backup file path.
    echo Usage: start.bat --restore ^<backup_file_path^>
    echo.
    echo Available backup files:
    if exist "%BACKUP_DIR%" (
        dir /b "%BACKUP_DIR%\*.tar.gz" 2>nul || echo   ^(No backup files^)
    ) else (
        echo   ^(Backup directory does not exist^)
    )
    exit /b 1
)

REM 支持相对路径
echo %RESTORE_PATH% | findstr /r "^[A-Za-z]:" >nul || set RESTORE_PATH=%~dp0%RESTORE_PATH%

if not exist "%RESTORE_PATH%" (
    echo Error: Backup file does not exist: %RESTORE_PATH%
    exit /b 1
)

REM 检查是否已有 .openclaw 目录
if exist ".openclaw" (
    if "%FORCE_MODE%"=="0" (
        echo Warning: .openclaw directory already exists in current location.
        echo Restore operation will overwrite existing data!
        echo.
        echo Please use --force to confirm overwrite:
        echo   start.bat --restore %RESTORE_PATH% --force
        echo.
        echo Or backup existing data first:
        echo   start.bat --backup
        exit /b 1
    )
    echo Warning: Will overwrite existing .openclaw directory
    rmdir /s /q ".openclaw" 2>nul
)

echo Restoring user data from backup...
echo Backup file: %RESTORE_PATH%

tar -xzf "%RESTORE_PATH%" 2>nul

if exist ".openclaw" (
    echo.
    echo Restore complete!
    echo Data directory: .openclaw\
    echo.
    echo Next step: Start the service
    echo   start.bat --daemon
    exit /b 0
) else (
    echo Error: Restore failed, please check if the backup file is corrupted.
    exit /b 1
)

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