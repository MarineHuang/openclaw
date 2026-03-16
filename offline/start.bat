@echo off
cd /d "%~dp0"

echo ============================================
echo  OpenClaw Offline
echo ============================================
echo.
echo  Starting OpenClaw Gateway...
echo  Open in browser after startup:
echo.
echo    http://127.0.0.1:18789/#token=(your token)
echo.
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

node-runtime\node.exe openclaw.mjs gateway --allow-unconfigured --port 18789

if %ERRORLEVEL% neq 0 (
    echo.
    echo  Startup failed. Error code: %ERRORLEVEL%
    echo  Check if port 18789 is already in use.
    echo.
    pause
)
