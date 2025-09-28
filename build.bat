@echo off
REM WireGuard-Go Windows 构建脚本
REM 替代 Makefile 的功能

setlocal enabledelayedexpansion

REM 设置颜色
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "NC=%ESC%[0m"

REM 检查参数
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
echo %BLUE%WireGuard-Go Windows 构建脚本%NC%
echo %BLUE%==============================%NC%
echo.
echo 可用命令:
echo   build         - 构建当前平台 (Windows)
echo   build-all     - 构建所有平台
echo   build-tools   - 构建命令行工具
echo   clean         - 清理构建文件
echo   test          - 运行测试
echo   deps          - 安装依赖
echo   help          - 显示此帮助
echo.
echo 使用示例:
echo   build.bat build
echo   build.bat build-all
echo   build.bat clean
goto :end

:build
echo %YELLOW%🔨 构建 Windows 版本...%NC%
go build -o wireguard-go.exe .
if %errorLevel% equ 0 (
    echo %GREEN%✅ Windows 构建完成: wireguard-go.exe%NC%
) else (
    echo %RED%❌ Windows 构建失败%NC%
    exit /b 1
)
goto :end

:build_all
echo %YELLOW%🔨 构建所有平台...%NC%

echo 构建 Windows...
go build -o wireguard-go-windows.exe .
if %errorLevel% equ 0 (
    echo %GREEN%✅ Windows 构建完成%NC%
) else (
    echo %RED%❌ Windows 构建失败%NC%
)

echo 构建 Linux...
set GOOS=linux
set GOARCH=amd64
go build -o wireguard-go-linux .
if %errorLevel% equ 0 (
    echo %GREEN%✅ Linux 构建完成%NC%
) else (
    echo %RED%❌ Linux 构建失败%NC%
)

echo 构建 macOS...
set GOOS=darwin
set GOARCH=amd64
go build -o wireguard-go-macos .
if %errorLevel% equ 0 (
    echo %GREEN%✅ macOS 构建完成%NC%
) else (
    echo %RED%❌ macOS 构建失败%NC%
)

REM 重置环境变量
set GOOS=
set GOARCH=

echo %GREEN%🎉 所有平台构建完成!%NC%
goto :end

:build_tools
echo %YELLOW%🔧 构建命令行工具...%NC%
cd cmd\wg-go
go build -o wg-go.exe .
if %errorLevel% equ 0 (
    echo %GREEN%✅ 命令行工具构建完成: cmd\wg-go\wg-go.exe%NC%
) else (
    echo %RED%❌ 命令行工具构建失败%NC%
    exit /b 1
)
cd ..\..

REM 构建 Linux/macOS 版本
set GOOS=linux
set GOARCH=amd64
go build -o wg-go-linux .
if %errorLevel% equ 0 (
    echo %GREEN%✅ Linux 命令行工具构建完成%NC%
) else (
    echo %RED%❌ Linux 命令行工具构建失败%NC%
)

set GOOS=darwin
set GOARCH=amd64
go build -o wg-go-macos .
if %errorLevel% equ 0 (
    echo %GREEN%✅ macOS 命令行工具构建完成%NC%
) else (
    echo %RED%❌ macOS 命令行工具构建失败%NC%
)

REM 重置环境变量
set GOOS=
set GOARCH=

goto :end

:clean
echo %YELLOW%🧹 清理构建文件...%NC%
if exist "wireguard-go.exe" del "wireguard-go.exe"
if exist "wireguard-go-windows.exe" del "wireguard-go-windows.exe"
if exist "wireguard-go-linux" del "wireguard-go-linux"
if exist "wireguard-go-macos" del "wireguard-go-macos"
if exist "cmd\wg-go\wg-go.exe" del "cmd\wg-go\wg-go.exe"
if exist "cmd\wg-go\wg-go-linux" del "cmd\wg-go\wg-go-linux"
if exist "cmd\wg-go\wg-go-macos" del "cmd\wg-go\wg-go-macos"
if exist "*.log" del "*.log"
echo %GREEN%✅ 清理完成%NC%
goto :end

:test
echo %YELLOW%🧪 运行测试...%NC%
go test ./...
if %errorLevel% equ 0 (
    echo %GREEN%✅ 测试完成%NC%
) else (
    echo %RED%❌ 测试失败%NC%
    exit /b 1
)
goto :end

:deps
echo %YELLOW%📦 安装依赖...%NC%
go mod tidy
go mod download
if %errorLevel% equ 0 (
    echo %GREEN%✅ 依赖安装完成%NC%
) else (
    echo %RED%❌ 依赖安装失败%NC%
    exit /b 1
)
goto :end

:end
