#!/bin/bash

# WireGuard-Go 快速启动脚本
# Quick Start Script for WireGuard-Go

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "🚀 WireGuard-Go 快速启动"
    echo "   Quick Start Script"
    echo "===================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}▶ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查权限
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "需要 root 权限来配置网络接口"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查必要文件
check_files() {
    print_step "1. 检查必要文件"
    
    if [[ ! -f "wireguard-go" ]]; then
        print_error "wireguard-go 不存在，请先编译"
        echo "运行: make 或 go build -o wireguard-go"
        exit 1
    fi
    
    # 检查 wg-go 工具是否存在
    WG_GO_PATH=""
    if [[ -f "cmd/wg-go/wg-go" ]]; then
        WG_GO_PATH="cmd/wg-go/wg-go"
        print_info "找到 wg-go 工具: cmd/wg-go/wg-go"
    elif [[ -f "wg-go" ]]; then
        WG_GO_PATH="wg-go"
        print_info "找到 wg-go 工具: wg-go"
    else
        print_error "wg-go 工具不存在，请先编译"
        echo "运行: cd cmd/wg-go && go build -o wg-go"
        echo "或者: go build -o wg-go"
        exit 1
    fi
    
    if [[ ! -f "wg0.conf" ]]; then
        print_error "配置文件 wg0.conf 不存在"
        exit 1
    fi
    
    print_success "所有必要文件存在"
}

# 停止现有连接
stop_existing() {
    print_step "2. 停止现有 WireGuard 连接"
    
    if pgrep -l wireguard-go >/dev/null 2>&1; then
        print_info "发现运行中的 WireGuard 进程，正在停止..."
        pkill wireguard-go
        sleep 2
        print_success "已停止现有进程"
    else
        print_info "没有运行中的 WireGuard 进程"
    fi
}

# 启动守护进程
start_daemon() {
    print_step "3. 启动 WireGuard 守护进程"
    
    print_info "启动 wireguard-go (默认启用 debug 日志)..."
    print_info "日志文件: $(pwd)/wireguard-go.log"
    print_info "日志仅写入文件，不会污染控制台输出"
    ./wireguard-go utun11 &
    
    print_info "等待接口创建..."
    sleep 3
    
    # 检查 utun11 接口是否创建成功
    if [[ ! -S "/var/run/wireguard/utun11.sock" ]]; then
        print_error "WireGuard 接口 utun11 创建失败"
        print_info "正在检查可能的原因..."
        
    # 检查进程是否还在运行
    if ! pgrep -l wireguard-go >/dev/null 2>&1; then
        print_error "WireGuard 进程已退出"
        print_info "可能的原因："
        print_info "  - utun11 接口已被占用"
        print_info "  - 权限不足"
        print_info "  - 系统不支持指定的接口名"
    else
        print_error "进程运行中但接口未创建"
    fi
        
        # 检查是否有其他 utun socket 被创建
        print_info "检查已创建的 WireGuard 接口:"
        ls -la /var/run/wireguard/ 2>/dev/null || print_info "  没有找到 WireGuard socket 文件"
        
        exit 1
    fi
    
    print_success "WireGuard 守护进程启动成功"
    print_success "接口 utun11 创建成功"
}

# 应用配置
apply_config() {
    print_step "4. 应用配置文件"
    
    print_info "应用 wg0.conf 到 utun11..."
    ./$WG_GO_PATH setconf utun11 wg0.conf
    
    print_info "检查配置应用结果..."
    CONFIG_OUTPUT=$(./$WG_GO_PATH show utun11)
    
    if echo "$CONFIG_OUTPUT" | grep -q "latest handshake"; then
        print_success "配置应用成功，握手已建立"
    else
        print_info "配置已应用，等待握手建立..."
    fi
}

# 配置网络
setup_network() {
    print_step "5. 配置网络接口"
    
    # 从配置文件提取 IP 地址
    VPN_IP=$(grep "Address" wg0.conf | cut -d'=' -f2 | tr -d ' ' | cut -d'/' -f1)
    
    if [[ -z "$VPN_IP" ]]; then
        print_error "无法从配置文件提取 IP 地址"
        exit 1
    fi
    
    print_info "配置接口 IP: $VPN_IP"
    # 使用 ip 命令（现代 Linux 系统）或 ifconfig（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        # 先启动接口
        if ip link set utun11 up 2>/dev/null; then
            print_success "接口 utun11 已启动"
        else
            print_error "接口 utun11 启动失败"
        fi
        # 然后配置 IP
        if ip addr add "$VPN_IP/32" dev utun11 2>/dev/null; then
            print_success "IP 地址配置成功: $VPN_IP"
        else
            print_error "IP 地址配置失败: $VPN_IP"
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        if ifconfig utun11 inet "$VPN_IP" "$VPN_IP" netmask 255.255.255.255 2>/dev/null; then
            print_success "IP 地址配置成功: $VPN_IP"
        else
            print_error "IP 地址配置失败: $VPN_IP"
        fi
    else
        print_error "无法找到网络配置工具 (ip 或 ifconfig)"
        exit 1
    fi
    
    print_info "添加路由..."
    # 从 AllowedIPs 提取网络段
    ALLOWED_IPS=$(grep "AllowedIPs" wg0.conf | cut -d'=' -f2 | tr -d ' ')
    
    IFS=',' read -ra NETWORKS <<< "$ALLOWED_IPS"
    for network in "${NETWORKS[@]}"; do
        network=$(echo "$network" | tr -d ' ')
        if [[ "$network" =~ ^192\.168\. ]]; then
            print_info "添加路由: $network"
            # 使用 ip 命令（现代 Linux 系统）或 route 命令（macOS/传统系统）
            if command -v ip >/dev/null 2>&1; then
                # 使用 ip 命令（Linux）
                if ip route add "$network" dev utun11 2>/dev/null; then
                    print_success "路由添加成功: $network"
                else
                    print_error "路由添加失败: $network"
                fi
            elif command -v route >/dev/null 2>&1; then
                # 使用 route 命令（macOS/传统系统）
                if route add -net "$network" -interface utun11 2>/dev/null; then
                    print_success "路由添加成功: $network"
                else
                    print_error "路由添加失败: $network"
                fi
            fi
        fi
    done
    
    print_success "网络配置完成"
}

# 验证连接
verify_connection() {
    print_step "6. 验证连接"
    
    print_info "检查接口状态..."
    # 使用 ip 命令（现代 Linux 系统）或 ifconfig（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        INTERFACE_STATUS=$(ip addr show utun11 2>/dev/null || echo "接口 utun11 不存在")
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        INTERFACE_STATUS=$(ifconfig utun11 2>/dev/null || echo "接口 utun11 不存在")
    else
        INTERFACE_STATUS="无法检查接口状态（缺少网络工具）"
    fi
    echo "$INTERFACE_STATUS"
    
    print_info "检查 WireGuard 状态..."
    WG_STATUS=$(./$WG_GO_PATH show utun11)
    echo "$WG_STATUS"
    
    print_info "检查路由..."
    # 使用 ip 命令（现代 Linux 系统）或 netstat（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        ip route show | grep utun11 || echo "  没有找到 utun11 相关路由"
    elif command -v netstat >/dev/null 2>&1; then
        # 使用 netstat 命令（macOS/传统系统）
        netstat -rn | grep utun11 || echo "  没有找到 utun11 相关路由"
    else
        echo "  无法检查路由（缺少网络工具）"
    fi
}

# 显示状态
show_status() {
    print_step "7. 连接状态总结"
    
    echo
    echo "🔗 WireGuard 连接信息:"
    ./$WG_GO_PATH show utun11
    
    echo
    echo "🌐 网络接口:"
    # 使用 ip 命令（现代 Linux 系统）或 ifconfig（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        ip addr show utun11 2>/dev/null | head -2 || echo "  接口 utun11 不存在"
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        ifconfig utun11 2>/dev/null | head -2 || echo "  接口 utun11 不存在"
    else
        echo "  无法检查接口状态（缺少网络工具）"
    fi
    
    echo
    echo "🛣️  相关路由:"
    # 使用 ip 命令（现代 Linux 系统）或 netstat（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        ip route show | grep utun11 || echo "  没有找到 utun11 相关路由"
    elif command -v netstat >/dev/null 2>&1; then
        # 使用 netstat 命令（macOS/传统系统）
        netstat -rn | grep utun11 || echo "  没有找到 utun11 相关路由"
    else
        echo "  无法检查路由（缺少网络工具）"
    fi
    
    echo
    echo "🔄 DNS 监控状态:"
    ./$WG_GO_PATH dns utun11 2>/dev/null || echo "  DNS 监控功能需要增强版 wireguard-go"
    
    echo
    echo "📋 日志文件:"
    echo "  位置: $(pwd)/wireguard-go.log"
    if [ -f "wireguard-go.log" ]; then
        echo "  大小: $(ls -lh wireguard-go.log | awk '{print $5}')"
        echo "  最新一条: $(tail -1 wireguard-go.log 2>/dev/null || echo 'N/A')"
    fi
    
    echo
    print_success "WireGuard 启动完成！"
    echo
    echo "📋 常用命令:"
    echo "  查看状态: sudo ./$WG_GO_PATH show utun11"
    echo "  实时监控: sudo ./$WG_GO_PATH monitor utun11"
    echo "  DNS 监控状态: sudo ./$WG_GO_PATH dns utun11"
    echo "  设置 DNS 监控: sudo ./$WG_GO_PATH dns utun11 <间隔秒数>"
    echo
    echo "📋 日志查看:"
    echo "  实时日志: tail -f wireguard-go.log"
    echo "  DNS 日志: grep 'DNS Monitor' wireguard-go.log"
    echo "  最新日志: tail -20 wireguard-go.log"
    echo
    echo "  停止服务: sudo pkill wireguard-go"
    echo
}

# 主函数
main() {
    print_header
    
    check_permissions
    check_files
    stop_existing
    start_daemon
    apply_config
    setup_network
    verify_connection
    show_status
    
    echo
    print_success "🎉 WireGuard-Go 快速启动完成！"
}

# 运行主函数
main "$@"
