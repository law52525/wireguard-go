@echo off
REM WireGuard-Go Windows 停止脚本

setlocal enabledelayedexpansion

REM 设置颜色
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "NC=%ESC%[0m"

echo %BLUE%========================================%NC%
echo %BLUE%  WireGuard-Go Windows 停止脚本%NC%
echo %BLUE%========================================%NC%
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%❌ 需要管理员权限运行此脚本%NC%
    echo 请右键点击命令提示符，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo %GREEN%✅ 管理员权限确认%NC%

REM 查找 WireGuard 进程
echo %YELLOW%🔍 查找 WireGuard 进程...%NC%
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe" >nul
if %errorLevel% neq 0 (
    echo %YELLOW%ℹ️  没有运行中的 WireGuard 进程%NC%
    goto :cleanup
)

echo %YELLOW%📋 发现运行中的进程:%NC%
tasklist /fi "imagename eq wireguard-go.exe"

echo.
echo %YELLOW%🛑 正在停止进程...%NC%

REM 尝试正常停止
taskkill /im wireguard-go.exe >nul 2>&1
timeout /t 2 /nobreak >nul

REM 检查是否还在运行
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe" >nul
if %errorLevel% equ 0 (
    echo %YELLOW%⚠️  正常停止失败，尝试强制停止...%NC%
    taskkill /f /im wireguard-go.exe >nul 2>&1
    timeout /t 1 /nobreak >nul
    
    REM 再次检查
    tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe" >nul
    if %errorLevel% equ 0 (
        echo %RED%❌ 无法停止 WireGuard 进程%NC%
        pause
        exit /b 1
    ) else (
        echo %GREEN%✅ 强制停止成功%NC%
    )
) else (
    echo %GREEN%✅ 正常停止成功%NC%
)

:cleanup
echo.
echo %YELLOW%🧹 清理资源...%NC%

REM 清理可能的 socket 文件 (Windows 使用命名管道)
REM 这里主要是清理日志文件
if exist "wireguard-go.log" (
    echo 保留日志文件: wireguard-go.log
    echo 如需清理日志，请手动删除
)

echo %GREEN%✅ 清理完成%NC%

echo.
echo %GREEN%✅ WireGuard-Go 已完全停止%NC%
echo.

pause
