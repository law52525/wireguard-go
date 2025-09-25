#!/bin/bash

# WireGuard-Go Linux 自动化测试脚本
# Automated Linux Testing Script for WireGuard-Go

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

print_header() {
    echo -e "${BLUE}"
    echo "🐧 WireGuard-Go Linux 自动化测试"
    echo "   Automated Linux Testing"
    echo "==============================="
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
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 检查权限
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo "需要 root 权限来运行网络测试"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 收集系统信息
collect_system_info() {
    print_step "收集系统信息"
    
    echo "测试环境信息:"
    echo "============="
    
    if command -v lsb_release >/dev/null 2>&1; then
        echo "发行版: $(lsb_release -d | cut -f2)"
    elif [ -f /etc/os-release ]; then
        echo "发行版: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    else
        echo "发行版: 未知"
    fi
    
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
    
    if command -v go >/dev/null 2>&1; then
        echo "Go 版本: $(go version)"
    else
        print_failure "Go 未安装"
        return 1
    fi
    
    echo "测试时间: $(date)"
    echo
}

# 测试编译
test_compilation() {
    print_step "测试编译"
    
    if [ ! -f "go.mod" ]; then
        print_failure "当前目录不是 WireGuard-Go 项目根目录"
        return 1
    fi
    
    print_info "编译主程序..."
    if go build -o wireguard-go . 2>/dev/null; then
        print_success "主程序编译成功"
    else
        print_failure "主程序编译失败"
        return 1
    fi
    
    print_info "编译命令行工具..."
    if go build -o cmd/wg-go/wg-go ./cmd/wg-go 2>/dev/null; then
        print_success "命令行工具编译成功"
    else
        print_failure "命令行工具编译失败"
        return 1
    fi
    
    print_info "检查可执行文件..."
    if [ -x "./wireguard-go" ] && [ -x "./cmd/wg-go/wg-go" ]; then
        print_success "可执行文件检查通过"
    else
        print_failure "可执行文件权限不正确"
        return 1
    fi
}

# 测试基础功能
test_basic_functionality() {
    print_step "测试基础功能"
    
    print_info "测试版本显示..."
    if ./wireguard-go --version >/dev/null 2>&1; then
        print_success "版本显示正常"
    else
        print_failure "版本显示失败"
    fi
    
    print_info "测试帮助信息..."
    if ./cmd/wg-go/wg-go --help >/dev/null 2>&1; then
        print_success "帮助信息正常"
    else
        print_failure "帮助信息失败"
    fi
    
    print_info "检查 TUN 模块..."
    if lsmod | grep -q tun || modprobe tun 2>/dev/null; then
        print_success "TUN 模块可用"
    else
        print_failure "TUN 模块不可用"
    fi
}

# 测试接口创建
test_interface_creation() {
    print_step "测试接口创建"
    
    local test_interface="wgtest0"
    
    print_info "启动测试守护进程..."
    LOG_LEVEL=verbose ./wireguard-go $test_interface &
    local wg_pid=$!
    
    sleep 3
    
    if kill -0 $wg_pid 2>/dev/null; then
        print_success "守护进程启动成功"
    else
        print_failure "守护进程启动失败"
        return 1
    fi
    
    print_info "检查接口创建..."
    if ip link show $test_interface >/dev/null 2>&1; then
        print_success "接口创建成功"
    else
        print_failure "接口创建失败"
        kill $wg_pid 2>/dev/null || true
        return 1
    fi
    
    print_info "检查 socket 文件..."
    if [ -S "/var/run/wireguard/${test_interface}.sock" ]; then
        print_success "Socket 文件创建成功"
    else
        print_failure "Socket 文件创建失败"
    fi
    
    print_info "测试 UAPI 通信..."
    if ./cmd/wg-go/wg-go show $test_interface >/dev/null 2>&1; then
        print_success "UAPI 通信正常"
    else
        print_failure "UAPI 通信失败"
    fi
    
    print_info "清理测试进程..."
    kill $wg_pid 2>/dev/null || true
    sleep 1
    rm -f /var/run/wireguard/${test_interface}.sock
}

# 测试 DNS 监控功能
test_dns_monitoring() {
    print_step "测试 DNS 监控功能"
    
    local test_interface="wgtest1"
    
    # 创建测试配置
    cat > test-config.conf << 'EOF'
[Interface]
PrivateKey = cPeO9I4gvLAn6NGZg4OfqzKabZebCnLAptIQOlYZPUo=

[Peer]
PublicKey = dUQKFvkC0jAtWmUBs4iMkf3xrhH9W8iJ2HkfqNkkMDk=
Endpoint = google.com:51820
AllowedIPs = 10.100.0.0/24
PersistentKeepalive = 25
EOF
    
    print_info "启动带 DNS 监控的守护进程..."
    LOG_LEVEL=verbose ./wireguard-go $test_interface &
    local wg_pid=$!
    
    sleep 3
    
    if ! kill -0 $wg_pid 2>/dev/null; then
        print_failure "DNS 测试守护进程启动失败"
        rm -f test-config.conf
        return 1
    fi
    
    print_info "检查 DNS Monitor 启动日志..."
    if grep -q "DNS Monitor: Starting" wireguard-go.log 2>/dev/null; then
        print_success "DNS Monitor 启动正常"
    else
        print_failure "DNS Monitor 启动失败"
    fi
    
    print_info "配置网络接口..."
    ip addr add 10.100.0.2/24 dev $test_interface 2>/dev/null || true
    ip link set $test_interface up 2>/dev/null || true
    
    print_info "应用包含域名的配置..."
    if ./cmd/wg-go/wg-go setconf $test_interface test-config.conf 2>/dev/null; then
        print_success "域名配置应用成功"
    else
        print_failure "域名配置应用失败"
    fi
    
    sleep 2
    
    print_info "检查域名检测日志..."
    if grep -q "Domain endpoint detected" wireguard-go.log 2>/dev/null; then
        print_success "域名端点检测正常"
    else
        print_failure "域名端点检测失败"
    fi
    
    print_info "检查 DNS 监控添加日志..."
    if grep -q "DNS Monitor: Added peer" wireguard-go.log 2>/dev/null; then
        print_success "DNS 监控添加正常"
    else
        print_failure "DNS 监控添加失败"
    fi
    
    print_info "测试 DNS 监控状态查询..."
    if ./cmd/wg-go/wg-go dns $test_interface 2>/dev/null | grep -q "Monitored peers: [1-9]"; then
        print_success "DNS 监控状态查询正常"
    else
        print_failure "DNS 监控状态查询失败"
    fi
    
    print_info "测试间隔设置..."
    if ./cmd/wg-go/wg-go dns $test_interface 30 2>/dev/null; then
        print_success "DNS 监控间隔设置正常"
    else
        print_failure "DNS 监控间隔设置失败"
    fi
    
    print_info "验证间隔设置..."
    if ./cmd/wg-go/wg-go dns $test_interface 2>/dev/null | grep -q "Check interval: 30"; then
        print_success "DNS 监控间隔验证正常"
    else
        print_failure "DNS 监控间隔验证失败"
    fi
    
    print_info "等待定期检查日志..."
    sleep 35
    if grep -q "DNS Monitor: Checking.*monitored peer" wireguard-go.log 2>/dev/null; then
        print_success "DNS 定期检查正常"
    else
        print_warning "DNS 定期检查日志未出现 (可能需要更长时间)"
    fi
    
    print_info "清理 DNS 测试..."
    kill $wg_pid 2>/dev/null || true
    sleep 1
    rm -f /var/run/wireguard/${test_interface}.sock test-config.conf
}

# 测试网络功能
test_network_functionality() {
    print_step "测试网络功能兼容性"
    
    local test_interface="wgtest2"
    
    print_info "启动网络测试守护进程..."
    ./wireguard-go $test_interface &
    local wg_pid=$!
    
    sleep 3
    
    print_info "测试 IP 地址配置..."
    if ip addr add 10.200.0.1/24 dev $test_interface 2>/dev/null; then
        print_success "IP 地址配置正常"
    else
        print_failure "IP 地址配置失败"
    fi
    
    print_info "测试接口启动..."
    if ip link set $test_interface up 2>/dev/null; then
        print_success "接口启动正常"
    else
        print_failure "接口启动失败"
    fi
    
    print_info "测试路由添加..."
    if ip route add 10.201.0.0/24 dev $test_interface 2>/dev/null; then
        print_success "路由添加正常"
    else
        print_failure "路由添加失败"
    fi
    
    print_info "测试路由查看..."
    if ip route show | grep -q "10.201.0.0/24 dev $test_interface"; then
        print_success "路由查看正常"
    else
        print_failure "路由查看失败"
    fi
    
    print_info "测试路由删除..."
    if ip route del 10.201.0.0/24 dev $test_interface 2>/dev/null; then
        print_success "路由删除正常"
    else
        print_failure "路由删除失败"
    fi
    
    print_info "清理网络测试..."
    kill $wg_pid 2>/dev/null || true
    sleep 1
    rm -f /var/run/wireguard/${test_interface}.sock
}

# 生成测试报告
generate_report() {
    print_step "生成测试报告"
    
    local report_file="linux-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > $report_file << EOF
WireGuard-Go Linux 支持测试报告
================================

测试环境:
$(collect_system_info 2>&1 | grep -E "(发行版|内核版本|架构|Go 版本|测试时间)")

测试结果:
=========
通过测试: $TESTS_PASSED
失败测试: $TESTS_FAILED
总计测试: $((TESTS_PASSED + TESTS_FAILED))

失败的测试项目:
EOF

    if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
        echo "无失败项目" >> $report_file
    else
        for test in "${FAILED_TESTS[@]}"; do
            echo "- $test" >> $report_file
        done
    fi
    
    cat >> $report_file << EOF

详细日志:
=========
$(tail -50 wireguard-go.log 2>/dev/null || echo "无日志文件")

结论:
=====
EOF

    if [ $TESTS_FAILED -eq 0 ]; then
        echo "✅ 完全支持 - Linux 平台无需任何修改即可使用" >> $report_file
        echo -e "${GREEN}✅ 完全支持 - Linux 平台无需任何修改即可使用${NC}"
    elif [ $TESTS_FAILED -le 2 ]; then
        echo "🔶 基本支持 - 需要小幅修改或配置调整" >> $report_file
        echo -e "${YELLOW}🔶 基本支持 - 需要小幅修改或配置调整${NC}"
    else
        echo "❌ 支持不足 - 需要显著修改才能在 Linux 上正常工作" >> $report_file
        echo -e "${RED}❌ 支持不足 - 需要显著修改才能在 Linux 上正常工作${NC}"
    fi
    
    echo
    echo "测试报告已保存到: $report_file"
}

# 清理函数
cleanup() {
    print_info "清理测试环境..."
    pkill wireguard-go 2>/dev/null || true
    rm -f /var/run/wireguard/wgtest*.sock
    rm -f test-config.conf
    sleep 1
}

# 主函数
main() {
    print_header
    
    check_permissions
    
    # 设置清理陷阱
    trap cleanup EXIT INT
    
    collect_system_info
    test_compilation
    test_basic_functionality
    test_interface_creation
    test_dns_monitoring
    test_network_functionality
    
    echo
    generate_report
    
    echo
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "🎉 所有测试通过！Linux 支持完美！"
    else
        print_warning "⚠️  有 $TESTS_FAILED 项测试失败，请查看报告详情"
    fi
}

# 运行主函数
main "$@"
