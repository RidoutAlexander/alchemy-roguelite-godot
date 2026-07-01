@echo off
setlocal

set "PROJECT_DIR=%~dp0.."
set "GIT=C:\Program Files\Git\cmd\git.exe"
set "GH=C:\Program Files\GitHub CLI\gh.exe"

if not exist "%GIT%" (
  echo Git is not installed. Install with: winget install Git.Git
  exit /b 1
)
if not exist "%GH%" (
  echo GitHub CLI is not installed. Install with: winget install GitHub.cli
  exit /b 1
)

pushd "%PROJECT_DIR%"

echo Checking GitHub login...
"%GH%" auth status >nul 2>&1
if errorlevel 1 (
  echo.
  echo Log in to GitHub first:
  echo   gh auth login
  echo.
  echo Choose: GitHub.com ^> HTTPS ^> Login with a web browser
  popd
  exit /b 1
)

set "REPO_NAME=alchemy-roguelite-godot"
echo.
echo Creating private GitHub repo: %REPO_NAME%
"%GH%" repo create %REPO_NAME% --private --source=. --remote=origin --push
if errorlevel 1 (
  echo.
  echo If the repo already exists, add it manually:
  echo   gh repo create %REPO_NAME% --private
  echo   git remote add origin https://github.com/YOUR_USERNAME/%REPO_NAME%.git
  echo   git push -u origin main
  popd
  exit /b 1
)

echo.
echo Done. Remote: origin ^(main^)
popd
endlocal