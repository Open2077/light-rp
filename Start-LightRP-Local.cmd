@echo off
rem OPEN//77 Official Roleplay — local test (no master, no license, loopback only).
rem Uses server.local.jsonc; the game client connects with the development preset
rem of the launcher or the "Open77 Development" flow. Not for a public server.
cd /d "%~dp0"
if exist server.env (
    for /f "usebackq eol=# tokens=1* delims==" %%A in ("server.env") do (
        if not "%%A"=="" set "%%A=%%B"
    )
)
Open77.Server.exe --config server.local.jsonc --no-setup %*
if errorlevel 1 pause
