#!/bin/bash

# WireGuard-Go 重启脚本
# WireGuard-Go Restart Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "🔄 WireGuard-Go 重启脚本"
    echo "   WireGuard-Go Restart Script"
    echo "============================"
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
        print_error "需要 root 权限来重启 WireGuard"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 停止现有的 WireGuard 进程
stop_wireguard() {
    print_step "1. 停止现有的 WireGuard 进程"
    
    # 查找并停止 wireguard-go 进程
    WG_PIDS=$(pgrep wireguard-go 2>/dev/null || true)
    if [ -n "$WG_PIDS" ]; then
        print_info "发现运行中的 WireGuard 进程: $WG_PIDS"
        print_info "正在停止进程..."
        pkill wireguard-go || true
        sleep 2
        
        # 强制杀死顽固进程
        WG_PIDS=$(pgrep wireguard-go 2>/dev/null || true)
        if [ -n "$WG_PIDS" ]; then
            print_info "强制停止顽固进程..."
            pkill -9 wireguard-go || true
            sleep 1
        fi
        
        print_success "WireGuard 进程已停止"
    else
        print_info "没有运行中的 WireGuard 进程"
    fi
    
    # 清理 socket 文件
    print_info "清理 socket 文件..."
    rm -f /var/run/wireguard/utun11.sock 2>/dev/null || true
    
    # 清理网络接口（如果存在）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        if ip link show utun11 >/dev/null 2>&1; then
            print_info "清理网络路由..."
            ip route del 192.168.11.0/24 2>/dev/null || true
            ip route del 192.168.10.0/24 2>/dev/null || true
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        if ifconfig utun11 >/dev/null 2>&1; then
            print_info "清理网络路由..."
            route delete -net 192.168.11.0/24 2>/dev/null || true
            route delete -net 192.168.10.0/24 2>/dev/null || true
        fi
    fi
}

# 检查必要文件
check_files() {
    print_step "2. 检查必要文件"
    
    if [ ! -f "./wireguard-go" ]; then
        print_error "wireguard-go 可执行文件不存在"
        echo "请先运行: go build -o wireguard-go ."
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
    
    if [ ! -f "wg0.conf" ]; then
        print_error "配置文件 wg0.conf 不存在"
        echo "请创建配置文件后重试"
        exit 1
    fi
    
    print_success "所有必要文件存在"
}

# 启动 WireGuard
start_wireguard() {
    print_step "3. 启动 WireGuard 守护进程"
    
    print_info "启动 wireguard-go (日志仅写入文件)..."
    print_info "日志文件: $(pwd)/wireguard-go.log"
    
    # 启动守护进程
    ./wireguard-go utun11 &
    
    print_info "等待接口创建..."
    sleep 3
    
    # 检查进程是否正常运行
    if ! pgrep -l wireguard-go >/dev/null 2>&1; then
        print_error "WireGuard 守护进程启动失败"
        echo "请检查日志文件: wireguard-go.log"
        exit 1
    fi
    
    print_success "WireGuard 守护进程已启动"
}

# 配置网络
configure_network() {
    print_step "3. 配置网络接口"
    
    print_info "配置接口 IP: 192.168.11.35"
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
        if ip addr add 192.168.11.35/32 dev utun11 2>/dev/null; then
            print_success "IP 地址配置成功: 192.168.11.35"
        else
            print_error "IP 地址配置失败: 192.168.11.35"
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        if ifconfig utun11 inet 192.168.11.35 192.168.11.35 netmask 255.255.255.255 2>/dev/null; then
            print_success "IP 地址配置成功: 192.168.11.35"
        else
            print_error "IP 地址配置失败: 192.168.11.35"
        fi
    fi
    
    print_info "添加路由..."
    # 使用 ip 命令（现代 Linux 系统）或 route 命令（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        if ip route add 192.168.11.0/24 dev utun11 2>/dev/null; then
            print_success "路由添加成功: 192.168.11.0/24"
        else
            print_error "路由添加失败: 192.168.11.0/24"
        fi
        if ip route add 192.168.10.0/24 dev utun11 2>/dev/null; then
            print_success "路由添加成功: 192.168.10.0/24"
        else
            print_error "路由添加失败: 192.168.10.0/24"
        fi
    elif command -v route >/dev/null 2>&1; then
        # 使用 route 命令（macOS/传统系统）
        if route add -net 192.168.11.0/24 -interface utun11 2>/dev/null; then
            print_success "路由添加成功: 192.168.11.0/24"
        else
            print_error "路由添加失败: 192.168.11.0/24"
        fi
        if route add -net 192.168.10.0/24 -interface utun11 2>/dev/null; then
            print_success "路由添加成功: 192.168.10.0/24"
        else
            print_error "路由添加失败: 192.168.10.0/24"
        fi
    fi
    
    print_success "网络配置完成"
}

# 应用配置
apply_config() {
    print_step "4. 应用 WireGuard 配置"
    
    print_info "应用 wg0.conf 到 utun11..."
    ./$WG_GO_PATH setconf utun11 wg0.conf
    
    print_info "等待握手建立..."
    sleep 2
    
    print_success "配置已应用"
}

# 验证连接
verify_connection() {
    print_step "5. 验证连接状态"
    
    # 检查接口状态
    print_info "检查接口状态..."
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        if ! ip link show utun11 >/dev/null 2>&1; then
            print_error "接口 utun11 不存在"
            exit 1
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        if ! ifconfig utun11 >/dev/null 2>&1; then
            print_error "接口 utun11 不存在"
            exit 1
        fi
    else
        print_error "无法检查接口状态（缺少网络工具）"
        exit 1
    fi
    
    # 检查 WireGuard 状态
    print_info "检查 WireGuard 状态..."
    if ! ./$WG_GO_PATH show utun11 >/dev/null 2>&1; then
        print_error "WireGuard 状态异常"
        exit 1
    fi
    
    # 测试网络连通性
    print_info "测试网络连通性..."
    # 使用兼容的 ping 参数（macOS 和 Linux）
    if ping -c 1 -W 5 192.168.11.21 >/dev/null 2>&1; then
        print_success "网络连通性测试成功！"
    else
        print_info "网络连通性测试未通过，可能目标不在线"
    fi
    
    print_success "连接验证完成"
}

# 显示状态
show_status() {
    print_step "6. 连接状态总结"
    
    echo
    echo "🔗 WireGuard 连接信息:"
    ./$WG_GO_PATH show utun11
    
    echo
    echo "📊 DNS 监控状态:"
    ./$WG_GO_PATH dns utun11 2>/dev/null || echo "  DNS 监控功能需要增强版 wireguard-go"
    
    echo
    echo "📋 日志文件:"
    echo "  位置: $(pwd)/wireguard-go.log"
    if [ -f "wireguard-go.log" ]; then
        echo "  大小: $(ls -lh wireguard-go.log | awk '{print $5}')"
        echo "  最新一条: $(tail -1 wireguard-go.log 2>/dev/null || echo 'N/A')"
    fi
    
    echo
    echo "📋 实用命令:"
    echo "  实时日志: tail -f wireguard-go.log"
    echo "  DNS 日志: grep 'DNS Monitor' wireguard-go.log"
    echo "  查看状态: sudo ./$WG_GO_PATH show utun11"
    echo "  实时监控: sudo ./$WG_GO_PATH monitor utun11"
    echo "  停止服务: sudo pkill wireguard-go"
}

# 主函数
main() {
    print_header
    
    check_permissions
    check_files
    stop_wireguard
    start_wireguard
    configure_network
    apply_config
    verify_connection
    show_status
    
    echo
    print_success "🎉 WireGuard-Go 重启完成！"
    echo
    print_info "重启后的服务将日志仅写入文件，控制台保持干净"
    print_info "使用 'tail -f wireguard-go.log' 查看实时日志"
}

# 处理 Ctrl+C
trap 'echo -e "\n${RED}❌ 重启被中断${NC}"; exit 1' INT

# 运行主函数
main "$@"
