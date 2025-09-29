@echo off
REM WireGuard-Go Windows Restart Script
REM Supports dynamic DNS monitoring functionality

setlocal enabledelayedexpansion

REM Color definitions
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

echo %BLUE%
echo 🔄 WireGuard-Go Windows 重启脚本
echo    WireGuard-Go Windows Restart Script
echo =====================================
echo %NC%

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%[ERROR] This script requires administrator privileges%NC%
    echo Please run as administrator
    pause
    exit /b 1
)

REM Configuration
set "CONFIG_FILE=wg0.conf"
set "INTERFACE_NAME=wg0"
set "WG_GO_PATH=cmd\wg-go\wg-go.exe"

echo %GREEN%[INFO] Starting WireGuard-Go restart process...%NC%

REM Step 1: Stop existing WireGuard processes
echo.
echo %YELLOW%[STEP 1] Stopping existing WireGuard processes...%NC%
taskkill /f /im wireguard-go.exe >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[OK] Existing processes stopped%NC%
) else (
    echo %YELLOW%[INFO] No running processes found%NC%
)

REM Step 2: Clean up network configuration
echo.
echo %YELLOW%[STEP 2] Cleaning up network configuration...%NC%

REM Read configuration from wg0.conf
if exist "%CONFIG_FILE%" (
    echo Reading configuration from %CONFIG_FILE%...
    
    REM Read AllowedIPs (peer networks)
    for /f "tokens=1* delims== " %%a in ('findstr /r "^AllowedIPs" %CONFIG_FILE%') do (
        set "ALLOWED_IPS=%%b"
    )
    
    if defined ALLOWED_IPS (
        echo %GREEN%[INFO] Found peer networks: %ALLOWED_IPS%%NC%
        
        REM Clean routes for each network in AllowedIPs
        for %%i in (%ALLOWED_IPS%) do (
            echo Cleaning route for %%i...
            route delete %%i >nul 2>&1
            if !errorLevel! == 0 (
                echo %GREEN%[OK] Route %%i cleaned%NC%
            ) else (
                echo %YELLOW%[INFO] Route %%i does not exist or already cleaned%NC%
            )
        )
    ) else (
        echo %YELLOW%[WARN] No AllowedIPs found in configuration%NC%
    )
) else (
    echo %YELLOW%[WARN] Configuration file %CONFIG_FILE% not found%NC%
)

REM Step 3: Check and compile if necessary
echo.
echo %YELLOW%[STEP 3] Checking and compiling if necessary...%NC%

REM Check if wireguard-go.exe exists
if exist "wireguard-go.exe" (
    echo %GREEN%[INFO] wireguard-go.exe already exists, skipping compilation%NC%
) else (
    REM Check Go environment before compiling
    echo %YELLOW%[CHECK] Checking Go environment...%NC%
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
    go build -o wireguard-go.exe .
    if %errorLevel% neq 0 (
        echo %RED%[ERROR] Compilation failed%NC%
        pause
        exit /b 1
    )
)

REM Check if wg-go.exe exists (check both possible locations)
if exist "wg-go.exe" (
    echo %GREEN%[INFO] wg-go.exe already exists in current directory, skipping compilation%NC%
    set "WG_GO_PATH=wg-go.exe"
) else if exist "%WG_GO_PATH%" (
    echo %GREEN%[INFO] wg-go.exe already exists in cmd\wg-go\, skipping compilation%NC%
    set "WG_GO_PATH=%WG_GO_PATH%"
) else (
    REM Check Go environment before compiling
    echo %YELLOW%[CHECK] Checking Go environment...%NC%
    go version >nul 2>&1
    if %errorLevel% neq 0 (
        echo %RED%[ERROR] Go is not installed or not added to PATH%NC%
        echo Please install Go first: https://golang.org/dl/
        pause
        exit /b 1
    )
    echo %GREEN%[OK] Go environment check passed%NC%
    
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
    set "WG_GO_PATH=cmd\wg-go\wg-go.exe"
)

echo %GREEN%[OK] Command line tool compilation successful%NC%

REM Check configuration file
if not exist "%CONFIG_FILE%" (
    echo %RED%[ERROR] Configuration file %CONFIG_FILE% not found%NC%
    echo Please create the configuration file first
    pause
    exit /b 1
)

echo %GREEN%[OK] All required files found%NC%

REM Step 4: Start WireGuard daemon
echo.
echo %YELLOW%[STEP 4] Starting WireGuard daemon...%NC%

REM Clean up old logs
set "LOG_FILE=wireguard-go.log"
if exist "%LOG_FILE%" del "%LOG_FILE%"

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

REM Step 5: Apply configuration
echo.
echo %YELLOW%[STEP 5] Applying configuration...%NC%
%WG_GO_PATH% setconf %INTERFACE_NAME% %CONFIG_FILE%
if %errorLevel% equ 0 (
    echo %GREEN%[OK] Configuration applied successfully%NC%
) else (
    echo %RED%[ERROR] Configuration application failed%NC%
    echo Please check the configuration file and try again
    pause
    exit /b 1
)

REM Step 6: Configure network interface
echo.
echo %YELLOW%[STEP 6] Configuring network interface...%NC%
echo Note: WireGuard-Go on Windows requires manual configuration of TUN interface IP and routes

REM Read configuration from wg0.conf
echo Reading configuration from %CONFIG_FILE%...

REM Read Address (interface IP)
for /f "tokens=2 delims== " %%a in ('findstr /r "^Address" %CONFIG_FILE%') do (
    set "INTERFACE_IP=%%a"
)
if not defined INTERFACE_IP (
    echo %RED%[ERROR] No Address found in configuration file%NC%
    pause
    exit /b 1
)

REM Read AllowedIPs (peer networks)
for /f "tokens=2 delims== " %%a in ('findstr /r "^AllowedIPs" %CONFIG_FILE%') do (
    set "ALLOWED_IPS=%%a"
)
if not defined ALLOWED_IPS (
    echo %RED%[ERROR] No AllowedIPs found in configuration file%NC%
    pause
    exit /b 1
)

echo %GREEN%[INFO] Interface IP: %INTERFACE_IP%%NC%
echo %GREEN%[INFO] Peer networks: %ALLOWED_IPS%%NC%

REM Extract IP and mask from interface IP (assuming /32 format)
for /f "tokens=1 delims=/" %%a in ("%INTERFACE_IP%") do set "INTERFACE_IP_ONLY=%%a"
set "INTERFACE_MASK=255.255.255.255"

echo Setting interface %INTERFACE_NAME% IP address to %INTERFACE_IP_ONLY%...
netsh interface ip set address "%INTERFACE_NAME%" static %INTERFACE_IP_ONLY% %INTERFACE_MASK%
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

REM Add routes for each network in AllowedIPs
for %%i in (%ALLOWED_IPS%) do (
    echo Adding route for %%i...
    route add %%i mask 255.255.255.0 %INTERFACE_IP_ONLY%
    if !errorLevel! equ 0 (
        echo %GREEN%[OK] Route %%i added successfully%NC%
    ) else (
        echo %YELLOW%[WARN] Route %%i may already exist%NC%
    )
)

REM Set DNS server
echo Setting DNS server...
netsh interface ip set dns "%INTERFACE_NAME%" static 8.8.8.8
if %errorLevel% equ 0 (
    echo %GREEN%[OK] DNS server set successfully%NC%
) else (
    echo %YELLOW%[WARN] DNS server setting failed%NC%
)

REM Step 7: Verify connection
echo.
echo %YELLOW%[STEP 7] Verifying connection...%NC%

REM Wait for interface creation
echo %YELLOW%[WAIT] Waiting for interface creation...%NC%
timeout /t 2 /nobreak >nul

REM Check if WireGuard is running
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe" >nul
if %errorLevel% neq 0 (
    echo %RED%[ERROR] WireGuard daemon is not running%NC%
    pause
    exit /b 1
)

echo %GREEN%[OK] WireGuard daemon is running%NC%

REM Check interface status
echo Checking interface status...
%WG_GO_PATH% show %INTERFACE_NAME%
if %errorLevel% neq 0 (
    echo %RED%[ERROR] Failed to retrieve interface status%NC%
    pause
    exit /b 1
)

echo %GREEN%[OK] Interface status retrieved successfully%NC%

REM Test network connectivity
echo Testing network connectivity...
REM Extract peer IP from Endpoint for testing
for /f "tokens=2 delims== " %%a in ('findstr /r "^Endpoint" %CONFIG_FILE%') do (
    set "ENDPOINT=%%a"
)
if defined ENDPOINT (
    for /f "tokens=1 delims=:" %%a in ("%ENDPOINT%") do set "PEER_IP=%%a"
    if defined PEER_IP (
        echo Testing connection to %PEER_IP%...
        ping -n 1 -w 5000 %PEER_IP% >nul 2>&1
        if !errorLevel! == 0 (
            echo %GREEN%[OK] Network connectivity test successful%NC%
        ) else (
            echo %YELLOW%[WARN] Network connectivity test failed, but WireGuard may still be working%NC%
        )
    ) else (
        echo %YELLOW%[INFO] Cannot extract peer IP for connectivity test%NC%
    )
) else (
    echo %YELLOW%[INFO] No Endpoint found for connectivity test%NC%
)

REM Step 8: Show final status
echo.
echo %YELLOW%[STEP 8] Final status...%NC%
echo.
echo %GREEN%[SUCCESS] WireGuard-Go restart completed successfully!%NC%
echo.
echo %BLUE%[INFO] Service Information:%NC%
echo   Interface: %INTERFACE_NAME%
echo   Config: %CONFIG_FILE%
echo   Interface IP: %INTERFACE_IP_ONLY%
echo   Peer Networks: %ALLOWED_IPS%
echo.
echo %BLUE%[INFO] Management Commands:%NC%
echo   Show status: %WG_GO_PATH% show %INTERFACE_NAME%
echo   Monitor: %WG_GO_PATH% monitor %INTERFACE_NAME%
echo   DNS status: %WG_GO_PATH% dns %INTERFACE_NAME% show
echo   Stop service: taskkill /F /IM wireguard-go.exe
echo.
echo %BLUE%[INFO] Logs:%NC%
echo   Logs are written to: wireguard-go.log
echo   Default log level: debug (verbose)
echo   Log output: file only (console stays clean)
echo.

pause
