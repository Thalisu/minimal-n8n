@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
cd /d "%ROOT%"
title n8n autostart

set "TASK_NAME=minimal-n8n"
set "START_SCRIPT=%ROOT%\windows\start-n8n.cmd"
set "SELF=%~f0"
set "ACTION=%~1"

net session >nul 2>&1 || goto :elevate

if /i "%ACTION%"=="remove" goto :remove
if not exist "%START_SCRIPT%" goto :missing_start
rem n8n creates this database on its first successful start. The task has no window, so a
rem start-n8n.cmd that stops on a validation error would hang there unseen.
if not exist "%ROOT%\data\.n8n\database.sqlite" goto :never_started

echo [autostart] Registering task "%TASK_NAME%" to run n8n at boot as %USERDOMAIN%\%USERNAME%
echo [autostart] Enter the Windows password of that account in the dialog. A PIN does not work.
rem Built with PowerShell instead of schtasks /create because schtasks cannot turn off the
rem defaults that would kill n8n: the 72 hour execution limit and the stop-on-battery rule.
rem The task runs as the user, not SYSTEM, because n8n is installed in that user's npm prefix.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$user = $env:USERDOMAIN + '\' + $env:USERNAME;" ^
  "$cred = Get-Credential -UserName $user -Message 'Windows password for the account that runs n8n at boot';" ^
  "if (-not $cred) { exit 2 };" ^
  "$q = [char]34;" ^
  "$action = New-ScheduledTaskAction -Execute $env:ComSpec -Argument ('/c ' + $q + $env:START_SCRIPT + $q) -WorkingDirectory $env:ROOT;" ^
  "$trigger = New-ScheduledTaskTrigger -AtStartup;" ^
  "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero);" ^
  "Register-ScheduledTask -TaskName $env:TASK_NAME -Action $action -Trigger $trigger -Settings $settings -User $user -Password $cred.GetNetworkCredential().Password -RunLevel Limited -Force | Out-Null"
if errorlevel 1 goto :register_failed

echo [autostart] Done. n8n starts on the next boot, before anyone logs in, with no window.
echo [autostart] Start it now:  schtasks /run /tn "%TASK_NAME%"
echo [autostart] Stop it:       schtasks /end /tn "%TASK_NAME%"
echo [autostart] Unregister:    windows\autostart.cmd remove
pause
exit /b 0

:remove
schtasks /query /tn "%TASK_NAME%" >nul 2>&1 || goto :not_registered
schtasks /end /tn "%TASK_NAME%" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f || goto :remove_failed
echo [autostart] Task "%TASK_NAME%" removed. n8n no longer starts at boot.
pause
exit /b 0

:elevate
echo [autostart] Administrator rights are required, requesting elevation
powershell -NoProfile -Command "if ($env:ACTION) { Start-Process -FilePath $env:SELF -ArgumentList $env:ACTION -Verb RunAs } else { Start-Process -FilePath $env:SELF -Verb RunAs }" || goto :elevate_failed
exit /b 0

:missing_start
echo [autostart] %START_SCRIPT% not found.
goto :fail

:never_started
echo [autostart] n8n has never started from this folder. Run windows\start-n8n.cmd once, wait until
echo [autostart] http://localhost:5678 opens, close it, then run this script again.
goto :fail

:register_failed
echo [autostart] Could not register the task. The password was wrong or the dialog was cancelled.
goto :fail

:not_registered
echo [autostart] Task "%TASK_NAME%" is not registered.
goto :fail

:remove_failed
echo [autostart] Could not remove the task. See the output above.
goto :fail

:elevate_failed
echo [autostart] Elevation was refused. Right-click this file and choose "Run as administrator".
goto :fail

:fail
pause
exit /b 1
