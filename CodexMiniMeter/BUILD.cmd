@echo off
setlocal
cd /d "%~dp0"
where dotnet >nul 2>&1
if errorlevel 1 (
  echo .NET 10 SDK not found. Install it from https://dotnet.microsoft.com/download/dotnet/10.0
  pause
  exit /b 1
)
rem Self-contained, single-file, windowless app for 64-bit Windows.
dotnet publish CodexMiniMeter.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish
if errorlevel 1 (
  echo Build failed.
  pause
  exit /b 1
)
echo.
echo Output: %CD%\publish\CodexMiniMeter.exe
echo Move the publish folder to a permanent location before enabling Start with Windows.
pause
