@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
cd /d "%ROOT%"
title n8n

if not exist ".env" goto :missing_env

for /f "usebackq eol=# tokens=1* delims==" %%A in (".env") do set "%%A=%%B"

if not defined N8N_VERSION goto :missing_version
if "%N8N_ENCRYPTION_KEY%"=="change-me" goto :default_key
if not defined N8N_ENCRYPTION_KEY goto :default_key

where node >nul 2>&1 || goto :missing_node
for /f "tokens=1 delims=v." %%M in ('node -v') do set "NODE_MAJOR=%%M"
rem isolated-vm 7 ships Windows prebuilds only for Node 24 (ABI 137) and 26 (ABI 147); other majors need Visual Studio Build Tools to compile it.
if not "%NODE_MAJOR%"=="24" if not "%NODE_MAJOR%"=="26" goto :wrong_node

for /f "delims=" %%P in ('npm prefix -g') do set "NPM_PREFIX=%%P"
set "N8N_INSTALLED="
if exist "%NPM_PREFIX%\node_modules\n8n\package.json" (
  for /f "delims=" %%V in ('node -p "require(process.argv[1]).version" "%NPM_PREFIX%\node_modules\n8n\package.json"') do set "N8N_INSTALLED=%%V"
)
if not "%N8N_INSTALLED%"=="%N8N_VERSION%" (
  echo [n8n] Installing n8n %N8N_VERSION%, installed: %N8N_INSTALLED%
  call npm install -g --no-fund --no-audit n8n@%N8N_VERSION% || goto :install_failed
)

rem Same memory budget as linux/docker-compose.yml: 512 MB main heap + 256 MB task runner heap.
set "NODE_OPTIONS=--max-old-space-size=512"
set "N8N_RUNNERS_MAX_OLD_SPACE_SIZE=256"
set "N8N_USER_FOLDER=%ROOT%\data"
set "N8N_RESTRICT_FILE_ACCESS_TO=%ROOT%\local-files"
rem n8n listens on every interface by default; linux/docker-compose.yml only publishes 127.0.0.1, so match it here.
if not defined N8N_LISTEN_ADDRESS set "N8N_LISTEN_ADDRESS=127.0.0.1"
if not defined N8N_PORT set "N8N_PORT=5678"
if not exist "%ROOT%\data" mkdir "%ROOT%\data"
if not exist "%ROOT%\local-files" mkdir "%ROOT%\local-files"

rem Checked once, before the restart loop: a second n8n on a taken port exits at once and this
rem script would relaunch it every 10 seconds forever, both writing to the same SQLite file.
node -e "require('net').createServer().once('error',()=>process.exit(1)).listen(+process.env.N8N_PORT,process.env.N8N_LISTEN_ADDRESS,function(){this.close()})" || goto :already_running

:run
echo [n8n] Starting n8n %N8N_VERSION% on http://localhost:%N8N_PORT%
call "%NPM_PREFIX%\n8n.cmd" start
echo [n8n] Exited with code %errorlevel%. Restarting in 10 seconds, close this window to stop.
timeout /t 10 /nobreak >nul
goto :run

:missing_env
echo [n8n] .env not found. Run windows\setup.cmd, or copy .env.example to .env and set N8N_ENCRYPTION_KEY.
goto :fail

:missing_version
echo [n8n] N8N_VERSION is missing in .env.
goto :fail

:default_key
echo [n8n] N8N_ENCRYPTION_KEY is still the placeholder. Set a random value in .env before the first start.
goto :fail

:missing_node
echo [n8n] Node.js not found. Run windows\setup.cmd, or install Node.js 26 LTS from https://nodejs.org and open a new terminal.
goto :fail

:wrong_node
echo [n8n] Node.js %NODE_MAJOR% detected. This setup requires Node.js 24 or 26 LTS.
goto :fail

:already_running
echo [n8n] %N8N_LISTEN_ADDRESS%:%N8N_PORT% is already in use, so n8n is probably running already.
echo [n8n] If the "minimal-n8n" autostart task started it, stop that with: schtasks /end /tn minimal-n8n
goto :fail

:install_failed
echo [n8n] npm install failed. See the output above.
goto :fail

:fail
pause
exit /b 1
