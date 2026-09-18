@echo off
rem OPEN//77 Official Roleplay — production start.
rem Loads server.env (license key, database) into the environment, then runs the
rem server with server.jsonc. Warden prints its setup PIN in this window on the
rem very first start; open http://127.0.0.1:11830/ and enter it.
cd /d "%~dp0"
if not exist server.env (
    echo server.env is missing: copy server.env.example to server.env and fill it in.
    pause
    exit /b 1
)
for /f "usebackq eol=# tokens=1* delims==" %%A in ("server.env") do (
    if not "%%A"=="" set "%%A=%%B"
)
if "%OP77_LICENSE_KEY%"=="" (
    echo OP77_LICENSE_KEY is empty in server.env. Create a key at https://open2077.net/account/keys
    echo or use Start-LightRP-Local.cmd for a local test without the master.
    pause
    exit /b 1
)
Open77.Server.exe --config server.jsonc --no-setup %*
if errorlevel 1 pause
