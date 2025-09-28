@echo off
REM WireGuard-Go Windows Stop Script

setlocal enabledelayedexpansion

REM Set colors
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "NC=%ESC%[0m"

echo %BLUE%========================================%NC%
echo %BLUE%  WireGuard-Go Windows Stop Script%NC%
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

REM Find WireGuard processes
echo %YELLOW%[SEARCH] Looking for WireGuard processes...%NC%
tasklist /fi "imagename eq wireguard-go.exe" 2>nul | find /i "wireguard-go.exe" >nul
if %errorLevel% == 0 (
    echo %YELLOW%[FOUND] Running processes found:%NC%
    tasklist /fi "imagename eq wireguard-go.exe"
) else (
    echo %YELLOW%[INFO] No running WireGuard processes found%NC%
    goto :cleanup
)

echo.
echo %YELLOW%[STOP] Stopping processes...%NC%
taskkill /f /im wireguard-go.exe >nul 2>&1
timeout /t 5 /nobreak >nul

REM Check again
tasklist /fi "imagename eq wireguard-go.exe" 2>nul | find /i "wireguard-go.exe" >nul
if %errorLevel% == 1 (
    echo %GREEN%[OK] Force stop successful%NC%
) else (
    echo %RED%[ERROR] Unable to stop WireGuard process%NC%
    pause
    exit /b 1
)

:cleanup
echo.
echo %YELLOW%[CLEANUP] Cleaning up resources...%NC%

REM Clean network configuration (Windows-specific steps)
echo %YELLOW%[NETWORK] Cleaning network configuration...%NC%

REM Clean routes to peer networks
echo Cleaning route configuration...
route delete 192.168.100.0 >nul 2>&1
if %errorLevel% == 0 (
    echo %GREEN%[OK] Route 192.168.100.0/24 cleaned%NC%
) else (
    echo %YELLOW%[INFO] Route 192.168.100.0/24 does not exist or already cleaned%NC%
)

route delete 192.168.101.0 >nul 2>&1
if %errorLevel% == 0 (
    echo %GREEN%[OK] Route 192.168.101.0/24 cleaned%NC%
) else (
    echo %YELLOW%[INFO] Route 192.168.101.0/24 does not exist or already cleaned%NC%
)

REM Check and clean wg0 interface configuration
echo Checking network interface status...
ipconfig | findstr "wg0" >nul 2>&1
if %errorLevel% == 0 (
    echo %YELLOW%[INFO] wg0 interface still exists, but WireGuard process stopped%NC%
    echo Note: Interface IP configuration will be preserved, needs reconfiguration on restart
    
    REM Ask if user wants to reset interface configuration
    echo.
    set /p "RESET_INTERFACE=Do you want to reset wg0 interface configuration? (y/N): "
    if /i "!RESET_INTERFACE!"=="y" (
        echo %YELLOW%[RESET] Resetting wg0 interface configuration...%NC%
        
        REM Reset interface to DHCP (this will change IP to auto-assigned)
        netsh interface ip set address "wg0" dhcp >nul 2>&1
        if %errorLevel% == 0 (
            echo %GREEN%[OK] wg0 interface reset to DHCP%NC%
        ) else (
            echo %RED%[ERROR] Failed to reset wg0 interface%NC%
        )
        
        REM Reset DNS to auto-assigned
        netsh interface ip set dns "wg0" dhcp >nul 2>&1
        if %errorLevel% == 0 (
            echo %GREEN%[OK] wg0 interface DNS reset%NC%
        ) else (
            echo %YELLOW%[WARN] Failed to reset wg0 interface DNS%NC%
        )
    ) else (
        echo %YELLOW%[INFO] Preserving wg0 interface configuration%NC%
    )
) else (
    echo %GREEN%[OK] wg0 interface automatically cleaned%NC%
)

REM Clean possible socket files (Windows uses named pipes)
REM Mainly cleaning log files here
if exist "wireguard-go.log" (
    echo Log file preserved: wireguard-go.log
    echo To clean logs, please delete manually
)

echo %GREEN%[OK] Cleanup completed%NC%

echo.
echo %GREEN%[SUCCESS] WireGuard-Go completely stopped%NC%
echo.

pause
