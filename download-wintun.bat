@echo off
REM Download wintun.dll for Windows development

setlocal enabledelayedexpansion

REM Set colors (simplified for better compatibility)
set "GREEN="
set "RED="
set "YELLOW="
set "BLUE="
set "NC="

echo ========================================
echo   WireGuard-Go Windows wintun.dll Download
echo ========================================
echo.

echo [INFO] Downloading wintun.dll for Windows development...

REM Create wintun directory
if not exist "wintun" mkdir wintun

REM Download wintun-0.14.1.zip
echo [INFO] Downloading wintun-0.14.1.zip...
powershell -Command "Invoke-WebRequest -Uri 'https://www.wintun.net/builds/wintun-0.14.1.zip' -OutFile 'wintun\wintun-0.14.1.zip'"
if %errorLevel% neq 0 (
    echo [ERROR] Failed to download wintun-0.14.1.zip
    pause
    exit /b 1
)

REM Extract all architectures
echo [INFO] Extracting wintun.dll for all architectures...
cd wintun
powershell -Command "Expand-Archive -Path 'wintun-0.14.1.zip' -DestinationPath '.' -Force"
cd ..

REM Verify extraction
if exist "wintun\wintun\bin" (
    echo [SUCCESS] wintun.dll extracted successfully
    echo Available architectures:
    dir wintun\wintun\bin
    
    echo.
    echo [INFO] wintun.dll files:
    for /r wintun\wintun\bin %%f in (wintun.dll) do echo %%f
    
    echo.
    echo [SUCCESS] wintun.dll ready for Windows development!
    echo Architecture mapping:
    echo   - amd64: wintun\wintun\bin\amd64\wintun.dll
    echo   - arm64: wintun\wintun\bin\arm64\wintun.dll
    echo   - 386:   wintun\wintun\bin\x86\wintun.dll
    echo   - arm:   wintun\wintun\bin\arm\wintun.dll
    
    REM Copy wintun.dll to current directory based on system architecture
    echo.
    echo [INFO] Copying wintun.dll to current directory...
    
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
        echo [WARNING] Unknown architecture: %PROCESSOR_ARCHITECTURE%, defaulting to amd64
        set "WINTUN_ARCH=amd64"
    )
    
    echo Detected architecture: %PROCESSOR_ARCHITECTURE% -^> !WINTUN_ARCH!
    
    REM Copy the appropriate wintun.dll
    if exist "wintun\wintun\bin\!WINTUN_ARCH!\wintun.dll" (
        copy "wintun\wintun\bin\!WINTUN_ARCH!\wintun.dll" "wintun.dll" >nul
        echo [SUCCESS] Copied wintun.dll for !WINTUN_ARCH! to current directory
    ) else (
        echo [ERROR] wintun.dll for !WINTUN_ARCH! not found
        echo Available architectures:
        dir wintun\wintun\bin
        pause
        exit /b 1
    )
    
    echo.
    echo [SUCCESS] Setup completed successfully!
    echo [INFO] Files in current directory:
    dir *.exe *.dll 2>nul
    
) else (
    echo [ERROR] Failed to extract wintun.dll
    pause
    exit /b 1
)

echo.
echo [SUCCESS] wintun.dll download and setup completed!
echo [INFO] You can now run: make build-windows
echo.

pause
