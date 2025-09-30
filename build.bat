@echo off
REM WireGuard-Go Windows Build Script
REM Alternative to Makefile functionality

setlocal enabledelayedexpansion

REM Check parameters
if "%1"=="" goto :help
if "%1"=="help" goto :help
if "%1"=="build" goto :build
if "%1"=="build-all" goto :build_all
if "%1"=="build-tools" goto :build_tools
if "%1"=="clean" goto :clean
if "%1"=="test" goto :test
if "%1"=="deps" goto :deps
goto :help

:help
echo WireGuard-Go Windows Build Script
echo ==================================
echo.
echo Available commands:
echo   build         - Build current platform (Windows)
echo   build-all     - Build all platforms
echo   build-tools   - Build command line tools
echo   clean         - Clean build files
echo   test          - Run tests
echo   deps          - Install dependencies
echo   help          - Show this help
echo.
echo Usage examples:
echo   build.bat build
echo   build.bat build-all
echo   build.bat clean
goto :end

:build
echo [INFO] Building Windows version...
go build -o wireguard-go.exe .
if %errorLevel% equ 0 (
    echo [SUCCESS] Windows build completed: wireguard-go.exe
) else (
    echo [ERROR] Windows build failed
    exit /b 1
)
goto :end

:build_all
echo [INFO] Building all platforms...

echo Building Windows...
go build -o wireguard-go-windows.exe .
if %errorLevel% equ 0 (
    echo [SUCCESS] Windows building completed
) else (
    echo [ERROR] Windows building failed
)

echo Building Linux...
set GOOS=linux
set GOARCH=amd64
go build -o wireguard-go-linux .
if %errorLevel% equ 0 (
    echo [SUCCESS] Linux building completed
) else (
    echo [ERROR] Linux building failed
)

echo Building macOS...
set GOOS=darwin
set GOARCH=amd64
go build -o wireguard-go-macos .
if %errorLevel% equ 0 (
    echo [SUCCESS] macOS building completed
) else (
    echo [ERROR] macOS building failed
)

REM Reset environment variables
set GOOS=
set GOARCH=

echo [SUCCESS] All platforms building completed!
goto :end

:build_tools
echo [INFO] Building command line tools...
cd cmd\wg-go
go build -o wg-go.exe .
if %errorLevel% equ 0 (
    echo [SUCCESS] Command line tools building completed: cmd\wg-go\wg-go.exe
) else (
    echo [ERROR] Command line tools building failed
    exit /b 1
)
cd ..\..

REM Building Linux/macOS versions
set GOOS=linux
set GOARCH=amd64
go build -o wg-go-linux .
if %errorLevel% equ 0 (
    echo [SUCCESS] Linux command line tools building completed
) else (
    echo [ERROR] Linux command line tools building failed
)

set GOOS=darwin
set GOARCH=amd64
go build -o wg-go-macos .
if %errorLevel% equ 0 (
    echo [SUCCESS] macOS command line tools building completed
) else (
    echo [ERROR] macOS command line tools building failed
)

REM Reset environment variables
set GOOS=
set GOARCH=

goto :end

:clean
echo [INFO] Cleaning build files...
if exist "wireguard-go.exe" del "wireguard-go.exe"
if exist "wireguard-go-windows.exe" del "wireguard-go-windows.exe"
if exist "wireguard-go-linux" del "wireguard-go-linux"
if exist "wireguard-go-macos" del "wireguard-go-macos"
if exist "cmd\wg-go\wg-go.exe" del "cmd\wg-go\wg-go.exe"
if exist "cmd\wg-go\wg-go-linux" del "cmd\wg-go\wg-go-linux"
if exist "cmd\wg-go\wg-go-macos" del "cmd\wg-go\wg-go-macos"
if exist "*.log" del "*.log"
echo [SUCCESS] Cleaning completed
goto :end

:test
echo [INFO] Running tests...
go test ./...
if %errorLevel% equ 0 (
    echo [SUCCESS] Tests completed
) else (
    echo [ERROR] Tests failed
    exit /b 1
)
goto :end

:deps
echo [INFO] Installing dependencies...
go mod tidy
go mod download
if %errorLevel% equ 0 (
    echo [SUCCESS] Dependencies installed
) else (
    echo [ERROR] Dependencies installation failed
    exit /b 1
)
goto :end

:end