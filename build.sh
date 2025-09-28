#!/bin/bash
# WireGuard-Go 跨平台构建脚本
# 支持 Linux, macOS, Windows

set -e

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "darwin";;
        CYGWIN*)    echo "windows";;
        MINGW*)     echo "windows";;
        MSYS*)      echo "windows";;
        *)          echo "unknown";;
    esac
}

OS=$(detect_os)

# 显示帮助
show_help() {
    echo -e "${BLUE}WireGuard-Go 构建脚本${NC}"
    echo -e "${BLUE}======================${NC}"
    echo
    echo "可用命令:"
    echo "  build         - 构建当前平台"
    echo "  build-all     - 构建所有平台"
    echo "  build-tools   - 构建命令行工具"
    echo "  clean         - 清理构建文件"
    echo "  test          - 运行测试"
    echo "  deps          - 安装依赖"
    echo "  help          - 显示此帮助"
    echo
    echo "使用示例:"
    echo "  ./build.sh build"
    echo "  ./build.sh build-all"
    echo "  ./build.sh clean"
}

# 构建当前平台
build_current() {
    echo -e "${YELLOW}🔨 构建当前平台 ($OS)...${NC}"
    
    if [ "$OS" = "windows" ]; then
        go build -o wireguard-go.exe .
        echo -e "${GREEN}✅ Windows 构建完成: wireguard-go.exe${NC}"
    else
        go build -o wireguard-go .
        echo -e "${GREEN}✅ $OS 构建完成: wireguard-go${NC}"
    fi
}

# 构建所有平台
build_all() {
    echo -e "${YELLOW}🔨 构建所有平台...${NC}"
    
    # Windows
    echo "构建 Windows..."
    GOOS=windows GOARCH=amd64 go build -o wireguard-go-windows.exe .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Windows 构建完成${NC}"
    else
        echo -e "${RED}❌ Windows 构建失败${NC}"
    fi
    
    # Linux
    echo "构建 Linux..."
    GOOS=linux GOARCH=amd64 go build -o wireguard-go-linux .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Linux 构建完成${NC}"
    else
        echo -e "${RED}❌ Linux 构建失败${NC}"
    fi
    
    # macOS
    echo "构建 macOS..."
    GOOS=darwin GOARCH=amd64 go build -o wireguard-go-macos .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ macOS 构建完成${NC}"
    else
        echo -e "${RED}❌ macOS 构建失败${NC}"
    fi
    
    echo -e "${GREEN}🎉 所有平台构建完成!${NC}"
}

# 构建命令行工具
build_tools() {
    echo -e "${YELLOW}🔧 构建命令行工具...${NC}"
    
    cd cmd/wg-go
    
    # 当前平台
    go build -o wg-go .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 当前平台命令行工具构建完成${NC}"
    else
        echo -e "${RED}❌ 当前平台命令行工具构建失败${NC}"
    fi
    
    # Windows
    GOOS=windows GOARCH=amd64 go build -o wg-go-windows.exe .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Windows 命令行工具构建完成${NC}"
    else
        echo -e "${RED}❌ Windows 命令行工具构建失败${NC}"
    fi
    
    # Linux
    GOOS=linux GOARCH=amd64 go build -o wg-go-linux .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Linux 命令行工具构建完成${NC}"
    else
        echo -e "${RED}❌ Linux 命令行工具构建失败${NC}"
    fi
    
    # macOS
    GOOS=darwin GOARCH=amd64 go build -o wg-go-macos .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ macOS 命令行工具构建完成${NC}"
    else
        echo -e "${RED}❌ macOS 命令行工具构建失败${NC}"
    fi
    
    cd ../..
}

# 清理
clean() {
    echo -e "${YELLOW}🧹 清理构建文件...${NC}"
    rm -f wireguard-go wireguard-go.exe
    rm -f wireguard-go-windows.exe wireguard-go-linux wireguard-go-macos
    rm -f cmd/wg-go/wg-go cmd/wg-go/wg-go.exe
    rm -f cmd/wg-go/wg-go-windows.exe cmd/wg-go/wg-go-linux cmd/wg-go/wg-go-macos
    rm -f *.log
    echo -e "${GREEN}✅ 清理完成${NC}"
}

# 运行测试
run_tests() {
    echo -e "${YELLOW}🧪 运行测试...${NC}"
    go test ./...
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 测试完成${NC}"
    else
        echo -e "${RED}❌ 测试失败${NC}"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    echo -e "${YELLOW}📦 安装依赖...${NC}"
    go mod tidy
    go mod download
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 依赖安装完成${NC}"
    else
        echo -e "${RED}❌ 依赖安装失败${NC}"
        exit 1
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        "build")
            build_current
            ;;
        "build-all")
            build_all
            ;;
        "build-tools")
            build_tools
            ;;
        "clean")
            clean
            ;;
        "test")
            run_tests
            ;;
        "deps")
            install_deps
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
