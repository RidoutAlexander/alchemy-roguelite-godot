@echo off
setlocal

set "PROJECT_DIR=%~dp0.."
set "GODOT=%GODOT_CONSOLE%"
if not defined GODOT set "GODOT=C:\Users\ridou\Downloads\Godot463\Godot_v4.6.3-stable_win64_console.exe"
set "EXPORT_DIR=%PROJECT_DIR%\exports"
set "EXE=%EXPORT_DIR%\AlchemyRoguelite.exe"
set "ZIP=%EXPORT_DIR%\AlchemyRoguelite-playtest.zip"

echo Exporting spreadsheet data...
py -3 "%PROJECT_DIR%\tools\export_ingredients.py"
if errorlevel 1 exit /b 1

if not exist "%GODOT%" (
  echo Godot console binary not found: %GODOT%
  echo Set GODOT_CONSOLE to your Godot_v4.6.3-stable_win64_console.exe path.
  exit /b 1
)

if not exist "%EXPORT_DIR%" mkdir "%EXPORT_DIR%"

echo Building Windows Desktop release...
"%GODOT%" --headless --path "%PROJECT_DIR%" --export-release "Windows Desktop" "%EXE%"
if errorlevel 1 exit /b 1

if not exist "%EXE%" (
  echo Export failed: %EXE% was not created.
  exit /b 1
)

echo Creating playtest ZIP...
powershell -NoProfile -Command "$files = Get-ChildItem -Path '%EXPORT_DIR%' -File | Where-Object { $_.Extension -in '.exe','.pck','.dll' -and $_.Name -notlike '*.tmp' }; if ($files.Count -eq 0) { throw 'No export artifacts found in exports folder.' }; if (Test-Path '%ZIP%') { Remove-Item '%ZIP%' -Force }; Compress-Archive -Path $files.FullName -DestinationPath '%ZIP%' -Force; Write-Host ('Packed {0} file(s) -> {1}' -f $files.Count, '%ZIP%')"

echo Done.
echo   EXE: %EXE%
echo   ZIP: %ZIP%
endlocal