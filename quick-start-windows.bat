@echo off
REM WireGuard-Go Windows 快速启动脚本
REM 支持动态 DNS 监控功能

setlocal enabledelayedexpansion

REM 设置颜色 (Windows 10+)
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "NC=%ESC%[0m"

REM 配置
set "INTERFACE_NAME=wg0"
set "CONFIG_FILE=wg0.conf"
set "LOG_FILE=wireguard-go.log"

echo %BLUE%========================================%NC%
echo %BLUE%  WireGuard-Go Windows 快速启动脚本%NC%
echo %BLUE%  支持动态 DNS 监控功能%NC%
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

REM 检查 Go 环境
go version >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%❌ Go 未安装或未添加到 PATH%NC%
    echo 请先安装 Go: https://golang.org/dl/
    pause
    exit /b 1
)

echo %GREEN%✅ Go 环境检查通过%NC%

REM 编译程序
echo %YELLOW%📦 编译 WireGuard-Go...%NC%
call build.bat build
if %errorLevel% neq 0 (
    echo %RED%❌ 编译失败%NC%
    pause
    exit /b 1
)

REM 编译命令行工具
echo %YELLOW%📦 编译命令行工具...%NC%
cd cmd\wg-go
go build -o wg-go.exe .
if %errorLevel% neq 0 (
    echo %RED%❌ 命令行工具编译失败%NC%
    pause
    exit /b 1
)
cd ..\..

echo %GREEN%✅ 命令行工具编译成功%NC%

REM 停止现有进程
echo %YELLOW%🛑 停止现有 WireGuard 进程...%NC%
taskkill /f /im wireguard-go.exe >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%✅ 已停止现有进程%NC%
) else (
    echo %YELLOW%ℹ️  没有运行中的进程%NC%
)

REM 清理旧日志
if exist "%LOG_FILE%" del "%LOG_FILE%"

REM 启动守护进程
echo %YELLOW%🚀 启动 WireGuard 守护进程...%NC%
echo 日志文件: %CD%\%LOG_FILE%
echo 日志仅写入文件，不会污染控制台输出
echo.

start /b wireguard-go.exe %INTERFACE_NAME%

REM 等待启动
timeout /t 3 /nobreak >nul

REM 检查进程是否启动
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe" >nul
if %errorLevel% neq 0 (
    echo %RED%❌ WireGuard 进程启动失败%NC%
    pause
    exit /b 1
)

echo %GREEN%✅ WireGuard 进程启动成功%NC%

REM 等待接口创建
echo %YELLOW%⏳ 等待接口创建...%NC%
timeout /t 2 /nobreak >nul

REM 应用配置
if exist "%CONFIG_FILE%" (
    echo %YELLOW%📋 应用配置文件...%NC%
    cmd\wg-go\wg-go.exe set %INTERFACE_NAME% < %CONFIG_FILE%
    if %errorLevel% equ 0 (
        echo %GREEN%✅ 配置应用成功%NC%
    ) else (
        echo %RED%❌ 配置应用失败%NC%
    )
) else (
    echo %YELLOW%⚠️  配置文件 %CONFIG_FILE% 不存在，跳过配置%NC%
)

REM 显示状态
echo.
echo %BLUE%========================================%NC%
echo %BLUE%  状态信息%NC%
echo %BLUE%========================================%NC%

echo %YELLOW%📊 进程状态:%NC%
tasklist /fi "imagename eq wireguard-go.exe" | find /i "wireguard-go.exe"

echo.
echo %YELLOW%📋 接口状态:%NC%
cmd\wg-go\wg-go.exe show %INTERFACE_NAME%

echo.
echo %YELLOW%🔍 DNS 监控状态:%NC%
cmd\wg-go\wg-go.exe dns %INTERFACE_NAME% show

echo.
echo %YELLOW%📝 日志文件:%NC%
if exist "%LOG_FILE%" (
    echo 日志文件: %CD%\%LOG_FILE%
    echo 最新日志:
    powershell "Get-Content '%LOG_FILE%' -Tail 5"
) else (
    echo 日志文件尚未生成
)

echo.
echo %GREEN%✅ WireGuard-Go 启动完成！%NC%
echo.
echo %YELLOW%💡 使用说明:%NC%
echo   - 查看状态: cmd\wg-go\wg-go.exe show %INTERFACE_NAME%
echo   - DNS 监控: cmd\wg-go\wg-go.exe dns %INTERFACE_NAME% show
echo   - 设置间隔: cmd\wg-go\wg-go.exe dns %INTERFACE_NAME% interval 30
echo   - 查看日志: type %LOG_FILE%
echo   - 停止服务: taskkill /f /im wireguard-go.exe
echo.

pause
