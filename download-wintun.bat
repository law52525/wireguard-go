@echo off
REM Download wintun.dll for Windows development

setlocal enabledelayedexpansion

REM Set colors
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "NC=%ESC%[0m"

echo %BLUE%========================================%NC%
echo %BLUE%  WireGuard-Go Windows wintun.dll Download%NC%
echo %BLUE%========================================%NC%
echo.

echo %YELLOW%📥 Downloading wintun.dll for Windows development...%NC%

REM Create wintun directory
if not exist "wintun" mkdir wintun

REM Download wintun-0.14.1.zip
echo Downloading wintun-0.14.1.zip...
powershell -Command "Invoke-WebRequest -Uri 'https://www.wintun.net/builds/wintun-0.14.1.zip' -OutFile 'wintun\wintun-0.14.1.zip'"
if %errorLevel% neq 0 (
    echo %RED%❌ Failed to download wintun-0.14.1.zip%NC%
    pause
    exit /b 1
)

REM Extract all architectures
echo Extracting wintun.dll for all architectures...
cd wintun
powershell -Command "Expand-Archive -Path 'wintun-0.14.1.zip' -DestinationPath '.' -Force"
cd ..

REM Verify extraction
if exist "wintun\wintun\bin" (
    echo %GREEN%✅ wintun.dll extracted successfully%NC%
    echo Available architectures:
    dir wintun\wintun\bin
    
    echo.
    echo %YELLOW%📋 wintun.dll files:%NC%
    for /r wintun\wintun\bin %%f in (wintun.dll) do echo %%f
    
    echo.
    echo %GREEN%🎉 wintun.dll ready for Windows development!%NC%
    echo Architecture mapping:
    echo   - amd64: wintun\wintun\bin\amd64\wintun.dll
    echo   - arm64: wintun\wintun\bin\arm64\wintun.dll
    echo   - 386:   wintun\wintun\bin\x86\wintun.dll
    echo   - arm:   wintun\wintun\bin\arm\wintun.dll
    
    REM Copy wintun.dll to current directory based on system architecture
    echo.
    echo %YELLOW%📋 Copying wintun.dll to current directory...%NC%
    
    REM Detect system architecture
    set "WINTUN_ARCH=amd64"
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
        set "WINTUN_ARCH=amd64"
    ) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
        set "WINTUN_ARCH=arm64"
    ) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
        set "WINTUN_ARCH=x86"
    ) else if "%PROCESSOR_ARCHITECTURE%"=="ARM" (
        set "WINTUN_ARCH=arm"
    ) else (
        echo %YELLOW%⚠️  Unknown architecture: %PROCESSOR_ARCHITECTURE%, defaulting to amd64%NC%
        set "WINTUN_ARCH=amd64"
    )
    
    echo Detected architecture: %PROCESSOR_ARCHITECTURE% -^> %WINTUN_ARCH%
    
    REM Copy the appropriate wintun.dll
    if exist "wintun\wintun\bin\%WINTUN_ARCH%\wintun.dll" (
        copy "wintun\wintun\bin\%WINTUN_ARCH%\wintun.dll" "wintun.dll" >nul
        echo %GREEN%✅ Copied wintun.dll for %WINTUN_ARCH% to current directory%NC%
    ) else (
        echo %RED%❌ wintun.dll for %WINTUN_ARCH% not found%NC%
        echo Available architectures:
        dir wintun\wintun\bin
        pause
        exit /b 1
    )
    
    echo.
    echo %GREEN%🎉 Setup completed successfully!%NC%
    echo %YELLOW%📋 Files in current directory:%NC%
    dir *.exe *.dll 2>nul
    
) else (
    echo %RED%❌ Failed to extract wintun.dll%NC%
    pause
    exit /b 1
)

echo.
echo %GREEN%✅ wintun.dll download and setup completed!%NC%
echo %YELLOW%💡 You can now run: make build-windows%NC%
echo.

pause
