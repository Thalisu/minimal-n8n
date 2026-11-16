@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
cd /d "%ROOT%"
title n8n setup

rem winget's OpenJS.NodeJS.LTS already serves Node 26, so the 24.x release has to be pinned.
set "NODE_VERSION=24.22.1"

call :check_node
if "%NODE_MAJOR%"=="24" goto :node_ok
if defined NODE_MAJOR goto :wrong_node

where winget >nul 2>&1 || goto :missing_winget
echo [setup] Installing Node.js %NODE_VERSION% with winget
winget install -e --id OpenJS.NodeJS.LTS --version %NODE_VERSION% --accept-source-agreements --accept-package-agreements || goto :node_install_failed
rem The installer updates PATH only for new terminals; add its default location for this session.
set "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
call :check_node
if not "%NODE_MAJOR%"=="24" goto :node_not_on_path

:node_ok
echo [setup] Node.js %NODE_MAJOR% found

if exist ".env" goto :env_ok
if not exist ".env.example" goto :missing_example
echo [setup] Creating .env with a random N8N_ENCRYPTION_KEY
node -e "const fs=require('fs');const k=require('crypto').randomBytes(32).toString('hex');fs.writeFileSync('.env',fs.readFileSync('.env.example','utf8').replace('N8N_ENCRYPTION_KEY=change-me','N8N_ENCRYPTION_KEY='+k))" || goto :env_failed
echo [setup] Back up .env. Losing N8N_ENCRYPTION_KEY makes every stored credential unreadable.

:env_ok
for /f "usebackq eol=# tokens=1* delims==" %%A in (".env") do if "%%A"=="N8N_VERSION" set "N8N_VERSION=%%B"
if not defined N8N_VERSION goto :missing_version

for /f "delims=" %%P in ('npm prefix -g') do set "NPM_PREFIX=%%P"
set "N8N_INSTALLED="
if exist "%NPM_PREFIX%\node_modules\n8n\package.json" (
  for /f "delims=" %%V in ('node -p "require(process.argv[1]).version" "%NPM_PREFIX%\node_modules\n8n\package.json"') do set "N8N_INSTALLED=%%V"
)
if "%N8N_INSTALLED%"=="%N8N_VERSION%" goto :n8n_ok
echo [setup] Installing n8n %N8N_VERSION%, installed: %N8N_INSTALLED%
call npm install -g --no-fund --no-audit n8n@%N8N_VERSION% || goto :n8n_install_failed

:n8n_ok
echo [setup] n8n %N8N_VERSION% is installed
echo [setup] Done. Start n8n with windows\start-n8n.cmd
pause
exit /b 0

:check_node
set "NODE_MAJOR="
where node >nul 2>&1 || exit /b 0
for /f "tokens=1 delims=v." %%M in ('node -v') do set "NODE_MAJOR=%%M"
exit /b 0

:wrong_node
echo [setup] Node.js %NODE_MAJOR% is installed, but this setup requires Node.js 24 LTS. Uninstall it or switch versions, then run this script again.
goto :fail

:missing_winget
echo [setup] winget not found. Install Node.js 24 LTS from https://nodejs.org and run this script again.
goto :fail

:node_install_failed
echo [setup] winget could not install Node.js. See the output above.
goto :fail

:node_not_on_path
echo [setup] Node.js was installed but is not on PATH yet. Open a new terminal and run this script again.
goto :fail

:missing_example
echo [setup] .env.example not found in %ROOT%.
goto :fail

:env_failed
echo [setup] Could not create .env.
goto :fail

:missing_version
echo [setup] N8N_VERSION is missing in .env.
goto :fail

:n8n_install_failed
echo [setup] npm install failed. See the output above.
goto :fail

:fail
pause
exit /b 1
