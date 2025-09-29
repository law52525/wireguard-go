#!/bin/bash

# WireGuard-Go 停止脚本
# Stop Script for WireGuard-Go

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "🛑 WireGuard-Go 停止脚本"
    echo "   Stop Script"
    echo "=================="
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
        print_error "需要 root 权限来停止 WireGuard"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 从配置文件读取网段信息
read_config_networks() {
    local config_file="wg0.conf"
    
    if [[ ! -f "$config_file" ]]; then
        print_info "配置文件 $config_file 不存在，使用默认网段"
        VPN_NETWORKS=("192.168.11.0/24" "192.168.10.0/24")
        return
    fi
    
    # 从 AllowedIPs 提取网络段
    ALLOWED_IPS=$(grep "AllowedIPs" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    if [[ -z "$ALLOWED_IPS" ]]; then
        print_info "未在配置文件中找到 AllowedIPs，使用默认网段"
        VPN_NETWORKS=("192.168.11.0/24" "192.168.10.0/24")
        return
    fi
    
    # 分割多个网段（用逗号分隔）
    IFS=',' read -ra VPN_NETWORKS <<< "$ALLOWED_IPS"
    for i in "${!VPN_NETWORKS[@]}"; do
        VPN_NETWORKS[$i]=$(echo "${VPN_NETWORKS[$i]}" | tr -d ' ')
    done
    
    print_info "发现 VPN 网段: ${VPN_NETWORKS[*]}"
}

# 停止 WireGuard 进程
stop_wireguard() {
    print_step "1. 停止 WireGuard 进程"
    
    if pgrep -l wireguard-go >/dev/null 2>&1; then
        print_info "发现运行中的 WireGuard 进程:"
        pgrep -l wireguard-go
        
        print_info "正在停止 WireGuard 进程..."
        pkill wireguard-go
        
        # 等待进程完全停止
        sleep 2
        
        if pgrep -l wireguard-go >/dev/null 2>&1; then
            print_error "进程仍在运行，尝试强制停止..."
            pkill -9 wireguard-go
            sleep 1
        fi
        
        print_success "WireGuard 进程已停止"
    else
        print_info "没有发现运行中的 WireGuard 进程"
    fi
}

# 检查接口状态
check_interfaces() {
    print_step "2. 检查网络接口状态"
    
    # 使用 ip 命令（现代 Linux 系统）或 ifconfig（macOS/传统系统）
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        if ip link show utun11 >/dev/null 2>&1; then
            print_info "utun11 接口仍然存在:"
            ip addr show utun11 | head -2
            print_info "接口通常会在进程停止后自动消失"
        else
            print_success "utun11 接口已清理"
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        if ifconfig utun11 >/dev/null 2>&1; then
            print_info "utun11 接口仍然存在:"
            ifconfig utun11 | head -2
            print_info "接口通常会在进程停止后自动消失"
        else
            print_success "utun11 接口已清理"
        fi
    else
        print_info "无法检查接口状态（缺少网络工具）"
    fi
    
    # 显示剩余的 utun 接口
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        UTUN_COUNT=$(ip link show | grep -c "^[0-9]*: utun" || true)
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        UTUN_COUNT=$(ifconfig | grep -c "^utun" || true)
    else
        UTUN_COUNT="未知"
    fi
    print_info "当前 utun 接口数量: $UTUN_COUNT"
}

# 清理路由
clean_routes() {
    print_step "3. 清理 VPN 路由"
    
    # 从配置文件读取网段信息
    read_config_networks
    
    # 检查是否有 VPN 相关路由
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        print_info "检查 VPN 相关路由..."
        FOUND_ROUTES=false
        
        # 检查每个配置的网段
        for network in "${VPN_NETWORKS[@]}"; do
            if ip route show | grep "$network" >/dev/null 2>&1; then
                if [[ "$FOUND_ROUTES" == false ]]; then
                    print_info "发现 VPN 相关路由:"
                    FOUND_ROUTES=true
                fi
                ip route show | grep "$network"
            fi
        done
        
        if [[ "$FOUND_ROUTES" == true ]]; then
            print_info "清理路由..."
            # 删除配置的 VPN 路由
            for network in "${VPN_NETWORKS[@]}"; do
                ip route del "$network" 2>/dev/null || true
                print_info "删除路由: $network"
            done
            
            # 检查是否还有全局 VPN 路由
            if ip route show | grep "0.0.0.0/1.*utun" >/dev/null 2>&1; then
                print_info "发现全局 VPN 路由，正在清理..."
                ip route del 0.0.0.0/1 2>/dev/null || true
                ip route del 128.0.0.0/1 2>/dev/null || true
            fi
            
            print_success "路由清理完成"
        else
            print_info "没有发现 VPN 相关路由"
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # 使用 netstat 命令（macOS/传统系统）
        print_info "检查 VPN 相关路由..."
        FOUND_ROUTES=false
        
        # 检查每个配置的网段
        for network in "${VPN_NETWORKS[@]}"; do
            if netstat -rn | grep "$network" >/dev/null 2>&1; then
                if [[ "$FOUND_ROUTES" == false ]]; then
                    print_info "发现 VPN 相关路由:"
                    FOUND_ROUTES=true
                fi
                netstat -rn | grep "$network"
            fi
        done
        
        if [[ "$FOUND_ROUTES" == true ]]; then
            print_info "清理路由..."
            # 删除配置的 VPN 路由
            for network in "${VPN_NETWORKS[@]}"; do
                route delete -net "$network" 2>/dev/null || true
                print_info "删除路由: $network"
            done
            
            # 检查是否还有全局 VPN 路由
            if netstat -rn | grep "0.0.0.0/1.*utun" >/dev/null 2>&1; then
                print_info "发现全局 VPN 路由，正在清理..."
                route delete -net 0.0.0.0/1 2>/dev/null || true
                route delete -net 128.0.0.0/1 2>/dev/null || true
            fi
            
            print_success "路由清理完成"
        else
            print_info "没有发现 VPN 相关路由"
        fi
    else
        print_info "无法检查路由（缺少网络工具）"
    fi
}

# 清理 Socket 文件
clean_sockets() {
    print_step "4. 清理 Socket 文件"
    
    SOCKET_DIR="/var/run/wireguard"
    
    if [[ -d "$SOCKET_DIR" ]]; then
        SOCKET_FILES=$(ls -1 "$SOCKET_DIR"/*.sock 2>/dev/null || true)
        
        if [[ -n "$SOCKET_FILES" ]]; then
            print_info "发现 Socket 文件:"
            ls -la "$SOCKET_DIR"/*.sock 2>/dev/null || true
            
            print_info "清理 Socket 文件..."
            rm -f "$SOCKET_DIR"/*.sock
            
            print_success "Socket 文件已清理"
        else
            print_info "没有发现 Socket 文件"
        fi
        
        # 显示目录状态
        print_info "Socket 目录状态:"
        ls -la "$SOCKET_DIR"
    else
        print_info "Socket 目录不存在"
    fi
}

# 验证清理结果
verify_cleanup() {
    print_step "5. 验证清理结果"
    
    # 检查进程
    if pgrep -l wireguard-go >/dev/null 2>&1; then
        print_error "WireGuard 进程仍在运行:"
        pgrep -l wireguard-go
    else
        print_success "✅ WireGuard 进程已完全停止"
    fi
    
    # 检查接口
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        if ip link show utun11 >/dev/null 2>&1; then
            print_info "⚠️  utun11 接口仍然存在"
        else
            print_success "✅ utun11 接口已清理"
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        if ifconfig utun11 >/dev/null 2>&1; then
            print_info "⚠️  utun11 接口仍然存在"
        else
            print_success "✅ utun11 接口已清理"
        fi
    else
        print_info "⚠️  无法检查接口状态（缺少网络工具）"
    fi
    
    # 检查路由
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        FOUND_ROUTES=false
        for network in "${VPN_NETWORKS[@]}"; do
            if ip route show | grep "$network" >/dev/null 2>&1; then
                if [[ "$FOUND_ROUTES" == false ]]; then
                    print_info "⚠️  仍有 VPN 相关路由:"
                    FOUND_ROUTES=true
                fi
                ip route show | grep "$network"
            fi
        done
        if [[ "$FOUND_ROUTES" == false ]]; then
            print_success "✅ VPN 路由已清理"
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # 使用 netstat 命令（macOS/传统系统）
        FOUND_ROUTES=false
        for network in "${VPN_NETWORKS[@]}"; do
            if netstat -rn | grep "$network" >/dev/null 2>&1; then
                if [[ "$FOUND_ROUTES" == false ]]; then
                    print_info "⚠️  仍有 VPN 相关路由:"
                    FOUND_ROUTES=true
                fi
                netstat -rn | grep "$network"
            fi
        done
        if [[ "$FOUND_ROUTES" == false ]]; then
            print_success "✅ VPN 路由已清理"
        fi
    else
        print_info "⚠️  无法检查路由（缺少网络工具）"
    fi
    
    # 检查 Socket
    SOCKET_FILES=$(ls -1 /var/run/wireguard/*.sock 2>/dev/null || true)
    if [[ -n "$SOCKET_FILES" ]]; then
        print_info "⚠️  仍有 Socket 文件"
    else
        print_success "✅ Socket 文件已清理"
    fi
}

# 显示清理后状态
show_final_status() {
    print_step "6. 清理后系统状态"
    
    echo
    echo "🔍 系统状态检查:"
    
    echo
    echo "📊 进程状态:"
    if pgrep -l wireguard >/dev/null 2>&1; then
        pgrep -l wireguard
    else
        echo "  没有 WireGuard 相关进程"
    fi
    
    echo
    echo "🌐 网络接口:"
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        UTUN_INTERFACES=$(ip link show | grep "^[0-9]*: utun" || true)
        if [[ -n "$UTUN_INTERFACES" ]]; then
            echo "$UTUN_INTERFACES"
        else
            echo "  没有 utun 接口"
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        # 使用 ifconfig 命令（macOS/传统系统）
        UTUN_INTERFACES=$(ifconfig | grep "^utun" || true)
        if [[ -n "$UTUN_INTERFACES" ]]; then
            echo "$UTUN_INTERFACES"
        else
            echo "  没有 utun 接口"
        fi
    else
        echo "  无法检查接口（缺少网络工具）"
    fi
    
    echo
    echo "🛣️  路由表 (VPN 相关):"
    if command -v ip >/dev/null 2>&1; then
        # 使用 ip 命令（Linux）
        FOUND_ROUTES=false
        for network in "${VPN_NETWORKS[@]}"; do
            if ip route show | grep "$network" >/dev/null 2>&1; then
                if [[ "$FOUND_ROUTES" == false ]]; then
                    FOUND_ROUTES=true
                fi
                ip route show | grep "$network"
            fi
        done
        if [[ "$FOUND_ROUTES" == false ]]; then
            echo "  没有 VPN 相关路由"
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # 使用 netstat 命令（macOS/传统系统）
        FOUND_ROUTES=false
        for network in "${VPN_NETWORKS[@]}"; do
            if netstat -rn | grep "$network" >/dev/null 2>&1; then
                if [[ "$FOUND_ROUTES" == false ]]; then
                    FOUND_ROUTES=true
                fi
                netstat -rn | grep "$network"
            fi
        done
        if [[ "$FOUND_ROUTES" == false ]]; then
            echo "  没有 VPN 相关路由"
        fi
    else
        echo "  无法检查路由（缺少网络工具）"
    fi
    
    echo
    print_success "WireGuard 清理完成！"
    echo
    echo "📋 如需重新启动:"
    echo "  sudo ./start.sh"
    echo
}

# 主函数
main() {
    print_header
    
    check_permissions
    read_config_networks  # 读取配置文件中的网段信息
    stop_wireguard
    check_interfaces
    clean_routes
    clean_sockets
    verify_cleanup
    show_final_status
    
    echo
    print_success "🎉 WireGuard-Go 停止完成！"
}

# 运行主函数
main "$@"
