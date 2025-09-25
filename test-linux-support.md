# Linux 支持测试方案
# Linux Support Testing Plan

## 🎯 测试目标

验证 WireGuard-Go 的动态 DNS 监控功能在 Linux 环境下是否能够无需任何代码修改即可完美运行。

## 🐧 测试环境要求

### 推荐的 Linux 发行版
- **Ubuntu 20.04/22.04 LTS** (最常用)
- **Debian 11/12** (稳定性好)
- **CentOS 8/9** (企业级)
- **Fedora 38+** (最新功能)

### 系统要求
- Go 1.19+ 
- root 权限或 sudo 访问
- 网络连接
- 基本的网络工具 (ping, ip, netstat)

## 📋 测试步骤

### 阶段 1: 环境准备

```bash
# 1. 安装 Go (如果未安装)
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# 2. 克隆项目
git clone <your-wireguard-go-repo>
cd wireguard-go

# 3. 编译项目
go build -o wireguard-go .
go build -o cmd/wg-go/wg-go ./cmd/wg-go

# 4. 检查编译结果
ls -la wireguard-go cmd/wg-go/wg-go
```

### 阶段 2: 基础功能测试

```bash
# 1. 测试基本帮助信息
./wireguard-go --version
./cmd/wg-go/wg-go --help

# 2. 检查 TUN 设备创建权限
sudo ./wireguard-go --help

# 3. 测试基本启动 (应该能正常创建接口)
sudo ./wireguard-go wg0 &
sleep 2
sudo pkill wireguard-go
```

### 阶段 3: 网络接口测试

```bash
# 1. 启动带日志的守护进程
sudo LOG_LEVEL=verbose ./wireguard-go wg0 &
WG_PID=$!

# 2. 检查接口是否创建
ip link show wg0
# 期望结果: 应该显示 wg0 接口

# 3. 检查 socket 文件
ls -la /var/run/wireguard/wg0.sock
# 期望结果: socket 文件存在且权限正确

# 4. 测试 UAPI 通信
sudo ./cmd/wg-go/wg-go show wg0
# 期望结果: 显示接口信息，无错误

# 5. 停止守护进程
sudo kill $WG_PID
```

### 阶段 4: DNS 监控功能测试

#### 4.1 创建测试配置文件

```bash
cat > linux-test.conf << 'EOF'
[Interface]
PrivateKey = YourPrivateKeyHere
Address = 10.0.0.2/24

[Peer]
PublicKey = YourPeerPublicKeyHere
Endpoint = example.com:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF
```

#### 4.2 测试 DNS 监控启动

```bash
# 1. 启动守护进程
sudo LOG_LEVEL=verbose ./wireguard-go wg0 &
WG_PID=$!
sleep 3

# 2. 检查 DNS 监控日志
grep "DNS Monitor" wireguard-go.log
# 期望结果: 应该显示 "DNS Monitor: Starting with 1m0s interval"

# 3. 配置网络接口
sudo ip addr add 10.0.0.2/24 dev wg0
sudo ip link set wg0 up

# 4. 应用配置 (包含域名端点)
sudo ./cmd/wg-go/wg-go setconf wg0 linux-test.conf

# 5. 检查 DNS 监控是否检测到域名
grep "Domain endpoint detected" wireguard-go.log
grep "DNS Monitor: Added peer" wireguard-go.log
# 期望结果: 应该显示域名检测和监控添加的日志

# 6. 检查 DNS 监控状态
sudo ./cmd/wg-go/wg-go dns wg0
# 期望结果: 显示监控状态，monitored peers > 0
```

#### 4.3 测试 DNS 监控配置

```bash
# 1. 设置监控间隔
sudo ./cmd/wg-go/wg-go dns wg0 30
# 期望结果: 成功设置为 30 秒

# 2. 验证间隔设置
sudo ./cmd/wg-go/wg-go dns wg0
# 期望结果: 显示 "Check interval: 30 seconds"

# 3. 观察定期检查日志
tail -f wireguard-go.log | grep "DNS Monitor"
# 期望结果: 每 30 秒看到 "DNS Monitor: Checking X monitored peer(s)"
```

### 阶段 5: 平台特定测试

#### 5.1 Linux 网络工具兼容性

```bash
# 1. 测试 ip 命令兼容性
ip route show | grep wg0
ip addr show wg0

# 2. 测试路由添加
sudo ip route add 192.168.100.0/24 dev wg0
ip route show | grep 192.168.100.0

# 3. 清理路由
sudo ip route del 192.168.100.0/24 dev wg0
```

#### 5.2 systemd 集成测试 (可选)

```bash
# 创建 systemd 服务文件
sudo tee /etc/systemd/system/wireguard-go-test.service << 'EOF'
[Unit]
Description=WireGuard-Go Test
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/wireguard-go
Environment=LOG_LEVEL=verbose
ExecStart=/path/to/wireguard-go/wireguard-go wg0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 测试服务启动
sudo systemctl daemon-reload
sudo systemctl start wireguard-go-test
sudo systemctl status wireguard-go-test

# 清理
sudo systemctl stop wireguard-go-test
sudo rm /etc/systemd/system/wireguard-go-test.service
sudo systemctl daemon-reload
```

## ✅ 成功标准

### 基础功能
- [ ] 编译无错误无警告
- [ ] 守护进程正常启动
- [ ] TUN 接口正常创建
- [ ] UAPI 通信正常
- [ ] 日志文件正常创建

### DNS 监控功能
- [ ] DNS Monitor 正常启动
- [ ] 域名端点正确检测
- [ ] 监控间隔可以设置和查询
- [ ] 定期 DNS 检查正常运行
- [ ] 日志记录完整准确

### 网络功能
- [ ] 接口 IP 配置正常
- [ ] 路由添加/删除正常
- [ ] 与 Linux 网络工具兼容

## 🐛 常见问题排查

### 权限问题
```bash
# 检查是否有 CAP_NET_ADMIN 权限
sudo setcap 'cap_net_admin+ep' ./wireguard-go
```

### TUN 设备问题
```bash
# 检查 TUN 模块是否加载
lsmod | grep tun
# 如果没有，加载模块
sudo modprobe tun
```

### Socket 权限问题
```bash
# 检查 /var/run/wireguard 目录
sudo mkdir -p /var/run/wireguard
sudo chmod 755 /var/run/wireguard
```

## 📊 测试报告模板

```bash
# 生成测试报告
cat > linux-test-report.txt << 'EOF'
Linux 支持测试报告
==================

测试环境:
- 发行版: $(lsb_release -d)
- 内核版本: $(uname -r)
- Go 版本: $(go version)
- 测试时间: $(date)

编译测试:
- [ ] 编译成功
- [ ] 无警告信息

基础功能测试:
- [ ] 守护进程启动
- [ ] 接口创建
- [ ] UAPI 通信

DNS 监控测试:
- [ ] DNS Monitor 启动
- [ ] 域名检测
- [ ] 间隔配置
- [ ] 定期检查

网络功能测试:
- [ ] IP 配置
- [ ] 路由操作
- [ ] 工具兼容性

问题记录:
- 无问题 / 详细描述遇到的问题

结论:
- ✅ 完全支持，无需修改
- 🔶 部分支持，需要小幅修改
- ❌ 不支持，需要大幅修改

备注:
EOF
```

## 🚀 自动化测试脚本

我还可以为您创建一个自动化测试脚本，一键运行所有测试并生成报告。需要吗？

## 📞 反馈渠道

测试完成后，请提供以下信息：
1. Linux 发行版和版本
2. 内核版本
3. 测试结果 (成功/失败的功能点)
4. 错误日志 (如果有)
5. 性能观察 (CPU/内存使用)

这样我们就能确定 Linux 支持的完整性，并根据需要进行相应的代码调整。
