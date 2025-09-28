@echo off
REM WireGuard-Go Windows Quick Start Script
REM Supports dynamic DNS monitoring functionality

setlocal enabledelayedexpansion

REM Set colors (Windows 10+)
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "NC=%ESC%[0m"

REM Configuration
set "INTERFACE_NAME=wg0"
set "CONFIG_FILE=wg0.conf"
set "LOG_FILE=wireguard-go.log"

echo %BLUE%========================================%NC%
echo %BLUE%  WireGuard-Go Windows Quick Start Script%NC%
echo %BLUE%  Supports Dynamic DNS Monitoring%NC%
echo %BLUE%========================================%NC%
echo.

REM Check administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%[ERROR] Administrator privileges required to run this script%NC%
    echo Please right-click Command Prompt and select "Run as administrator"
    pause
    exit /b 1
)

echo %GREEN%[OK] Administrator privileges confirmed%NC%

REM Check Go environment
go version >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%[ERROR] Go is not installed or not added to PATH%NC%
    echo Please install Go first: https://golang.org/dl/
    pause
    exit /b 1
)

echo %GREEN%[OK] Go environment check passed%NC%

REM Compile program
echo %YELLOW%[BUILD] Compiling WireGuard-Go...%NC%
call build.bat build
if %errorLevel% neq 0 (
    echo %RED%[ERROR] Compilation failed%NC%
    pause
    exit /b 1
)

REM Compile command line tool
echo %YELLOW%[BUILD] Compiling command line tool...%NC%
cd cmd\wg-go
go build -o wg-go.exe .
if %errorLevel% neq 0 (
    echo %RED%[ERROR] Command line tool compilation failed%NC%
    pause
    exit /b 1
)
cd ..\..

echo %GREEN%[OK] Command line tool compilation successful%NC%

REM Stop existing processes
echo %YELLOW%[STOP] Stopping existing WireGuard processes...%NC%
taskkill /f /im wireguard-go.exe >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[OK] Existing processes stopped%NC%
) else (
    echo %YELLOW%[INFO] No running processes found%NC%
)

REM Clean up old logs
if exist "%LOG_FILE%" del "%LOG_FILE%"

REM Start daemon process
echo %YELLOW%[START] Starting WireGuard daemon process...%NC%
echo Log file: %CD%\%LOG_FILE%
echo Logs are written to file only, console output is clean
echo.

start /b wireguard-go.exe %INTERFACE_NAME%

REM Wait for startup
timeout /t 3 /nobreak >nul

REM Check if process started
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe" >nul
if %errorLevel% neq 0 (
    echo %RED%[ERROR] WireGuard process startup failed%NC%
    pause
    exit /b 1
)

echo %GREEN%[OK] WireGuard process started successfully%NC%

REM Wait for interface creation
echo %YELLOW%[WAIT] Waiting for interface creation...%NC%
timeout /t 2 /nobreak >nul

REM Apply configuration
if exist "%CONFIG_FILE%" (
    echo %YELLOW%[CONFIG] Applying configuration file...%NC%
    cmd\wg-go\wg-go.exe setconf %INTERFACE_NAME% %CONFIG_FILE%
    if %errorLevel% equ 0 (
        echo %GREEN%[OK] Configuration applied successfully%NC%
    ) else (
        echo %RED%[ERROR] Configuration application failed%NC%
    )
) else (
    echo %YELLOW%[WARN] Configuration file %CONFIG_FILE% not found, skipping configuration%NC%
)

REM Configure network interface (Windows-specific steps)
echo %YELLOW%[NETWORK] Configuring network interface...%NC%
echo Note: WireGuard-Go on Windows requires manual configuration of TUN interface IP and routes

REM Read IP address from config file (simplified version, assuming 192.168.101.20)
set "INTERFACE_IP=192.168.101.20"
set "INTERFACE_MASK=255.255.255.0"

echo Setting interface %INTERFACE_NAME% IP address to %INTERFACE_IP%...
netsh interface ip set address "%INTERFACE_NAME%" static %INTERFACE_IP% %INTERFACE_MASK%
if %errorLevel% equ 0 (
    echo %GREEN%[OK] Interface IP address set successfully%NC%
) else (
    echo %RED%[ERROR] Interface IP address setting failed%NC%
    echo Please check interface name and permissions
)


REM Add routes to peer networks
echo Adding routes to peer networks...
echo Waiting 5 seconds for interface to stabilize...
timeout /t 5 /nobreak >nul
REM Use interface name instead of IP for routing
route add 192.168.100.0 mask 255.255.255.0 192.168.101.1
if %errorLevel% equ 0 (
    echo %GREEN%[OK] Route 192.168.100.0/24 added successfully%NC%
) else (
    echo %YELLOW%[WARN] Route 192.168.100.0/24 may already exist%NC%
)

route add 192.168.101.0 mask 255.255.255.0 192.168.101.1
if %errorLevel% equ 0 (
    echo %GREEN%[OK] Route 192.168.101.0/24 added successfully%NC%
) else (
    echo %YELLOW%[WARN] Route 192.168.101.0/24 may already exist%NC%
)

REM Set DNS server
echo Setting DNS server...
netsh interface ip set dns "%INTERFACE_NAME%" static 8.8.8.8
if %errorLevel% equ 0 (
    echo %GREEN%[OK] DNS server set successfully%NC%
) else (
    echo %YELLOW%[WARN] DNS server setting failed, using system default%NC%
)

REM Display status
echo.
echo %BLUE%========================================%NC%
echo %BLUE%  Status Information%NC%
echo %BLUE%========================================%NC%

echo %YELLOW%[PROCESS] Process Status:%NC%
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe"

echo.
echo %YELLOW%[INTERFACE] Interface Status:%NC%
cmd\wg-go\wg-go.exe show %INTERFACE_NAME%

echo.
echo %YELLOW%[DNS] DNS Monitoring Status:%NC%
cmd\wg-go\wg-go.exe dns %INTERFACE_NAME% show

echo.
echo %YELLOW%[LOG] Log File:%NC%
if exist "%LOG_FILE%" (
    echo Log file: %CD%\%LOG_FILE%
    echo Latest logs:
    powershell "Get-Content '%LOG_FILE%' -Tail 5"
) else (
    echo Log file not generated yet
)

echo.
echo %GREEN%[SUCCESS] WireGuard-Go startup completed!%NC%
echo.
echo %YELLOW%[USAGE] Usage Instructions:%NC%
echo   - View status: cmd\wg-go\wg-go.exe show %INTERFACE_NAME%
echo   - DNS monitoring: cmd\wg-go\wg-go.exe dns %INTERFACE_NAME% show
echo   - Set interval: cmd\wg-go\wg-go.exe dns %INTERFACE_NAME% interval 30
echo   - View logs: type %LOG_FILE%
echo   - Stop service: taskkill /f /im wireguard-go.exe
echo.

pause