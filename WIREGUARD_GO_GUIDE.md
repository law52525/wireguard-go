# 🔧 WireGuard-Go 完整指南

> 基于官方 WireGuard-Go 的增强实现，包含自制管理工具和跨平台自动化脚本

## 📋 目录
- [项目概述](#-项目概述)
- [项目结构](#-项目结构)
- [环境准备](#-环境准备)
- [快速开始](#-快速开始)
- [详细使用](#-详细使用)
- [命令参考](#-命令参考)
- [故障排除](#-故障排除)
- [技术说明](#-技术说明)

---

## 🌟 项目概述

### 特色功能
- **🔧 wg-go 管理工具**: 自制的 Go 版本 WireGuard 管理工具
- **🚀 跨平台自动化脚本**: 一键启动、重启、停止脚本 (支持 Windows/Linux/macOS)
- **🌐 智能域名解析**: 自动将域名解析为 IP 地址
- **🔄 动态 DNS 监控**: 自动监控域名端点的 IP 变化并重新连接
- **🔑 智能密钥转换**: Base64 ↔ Hex 格式自动转换
- **📊 实时监控**: 连接状态和流量统计的实时监控
- **🖥️ 跨平台支持**: 完整支持 Windows、Linux、macOS
- **📦 构建系统**: Makefile 和构建脚本支持多平台编译

### 解决的问题
1. **官方 wg 工具依赖**: 无需安装 wireguard-tools
2. **动态 IP 问题**: 自动监控和处理域名端点的 IP 变化
3. **域名解析**: 支持域名端点，自动解析为 IP
4. **超时处理**: 防止命令挂起的智能超时
5. **权限管理**: 友好的权限检查和提示
6. **跨平台部署**: 统一的脚本和构建系统

---

## 📁 项目结构

```
wireguard-go/
├── 🔧 核心程序
│   ├── main.go                   # Linux/macOS 主程序入口
│   ├── main_windows.go           # Windows 主程序入口
│   └── cmd/wg-go/                # 命令行管理工具
│       ├── main.go               # 主程序入口
│       ├── commands.go           # 命令处理逻辑
│       ├── uapi.go               # UAPI 通信接口
│       ├── uapi_unix.go          # Unix 平台 UAPI 实现
│       ├── uapi_windows.go       # Windows 平台 UAPI 实现
│       ├── crypto.go             # 密钥生成和管理
│       ├── monitor.go            # 实时监控功能
│       ├── go.mod                # Go 模块文件
│       └── go.sum                # 依赖校验文件
│
├── 🚀 自动化脚本
│   ├── start.sh                  # Linux/macOS 启动脚本
│   ├── restart.sh                # Linux/macOS 重启脚本
│   ├── stop.sh                   # Linux/macOS 停止脚本
│   ├── start.bat                 # Windows 启动脚本
│   ├── restart.bat               # Windows 重启脚本
│   └── stop.bat                  # Windows 停止脚本
│
├── 🔨 构建系统
│   ├── Makefile                  # 跨平台构建配置
│   ├── build.sh                  # Linux/macOS 构建脚本
│   ├── build.bat                 # Windows 构建脚本
│   └── download-wintun.sh        # Windows wintun.dll 下载脚本
│
├── 📚 文档
│   ├── WIREGUARD_GO_GUIDE.md     # 完整指南
│   └── README.md                 # 项目说明
│
└── 📦 原始 WireGuard-Go 源码
    ├── conn/                     # 网络连接处理
    ├── device/                   # 设备管理 (含 DNS 监控)
    ├── ipc/                      # 进程间通信
    ├── tun/                      # TUN 接口处理
    ├── ratelimiter/              # 速率限制
    ├── replay/                   # 重放保护
    ├── tai64n/                   # 时间戳
    └── ...                       # 其他原始文件
```

---

## 🔧 环境准备

### 系统要求
- **操作系统**: 
  - Windows 10/11 (x64, ARM64)
  - macOS 10.15+ (Intel, Apple Silicon)
  - Linux (Ubuntu 18.04+, CentOS 7+, 其他发行版需测试)
- **Go 版本**: Go 1.19+ (推荐 Go 1.21+)
- **权限**: 
  - Windows: 管理员权限
  - Linux/macOS: sudo 权限

### 环境检查

#### Linux/macOS
```bash
# 检查 Go 版本
go version

# 检查权限
sudo echo "权限检查通过"

# 检查网络工具
ifconfig utun0 >/dev/null 2>&1 && echo "网络权限正常"
```

#### Windows
```cmd
REM 检查 Go 版本
go version

REM 检查管理员权限
net session >nul 2>&1 && echo "管理员权限正常" || echo "需要管理员权限"

REM 检查网络工具
ipconfig >nul 2>&1 && echo "网络工具正常"
```

### 编译项目

#### 方法一：使用 Makefile (推荐)

**Linux/macOS:**
```bash
# 进入项目目录
cd wireguard-go

# 查看帮助
make help

# 构建当前平台
make build

# 构建所有平台
make build-all

# 构建命令行工具
make build-tools

# 清理
make clean
```

**Windows (需要安装 Make):**
```cmd
REM 安装 Make (使用 Chocolatey)
choco install make

REM 或者使用 Scoop
scoop install make

REM 然后使用 Makefile
make help
make build
```

#### 方法二：使用构建脚本

**Linux/macOS:**
```bash
# 使用构建脚本
./build.sh build

# 构建所有平台
./build.sh build-all

# 构建命令行工具
./build.sh build-tools
```

**Windows:**
```cmd
REM 使用构建脚本
build.bat build

REM 构建所有平台
build.bat build-all

REM 构建命令行工具
build.bat build-tools
```

#### 方法三：手动编译

**Linux/macOS:**
```bash
# 进入项目目录
cd wireguard-go

# 1. 编译 WireGuard 守护进程
go build -o wireguard-go .

# 2. 编译 wg-go 管理工具
cd cmd/wg-go
go build -o wg-go .
cd ../..

# 验证编译结果
./cmd/wg-go/wg-go help
ls -la wireguard-go cmd/wg-go/wg-go
```

**Windows:**
```cmd
REM 进入项目目录
cd wireguard-go

REM 1. 下载 wintun.dll (首次编译需要)
make download-wintun

REM 2. 编译 WireGuard 守护进程
go build -o wireguard-go.exe .

REM 3. 编译 wg-go 管理工具
cd cmd\wg-go
go build -o wg-go.exe .
cd ..\..

REM 验证编译结果
cmd\wg-go\wg-go.exe help
dir wireguard-go.exe cmd\wg-go\wg-go.exe
```

### Windows 特殊依赖

#### wintun.dll 下载
```bash
# 使用脚本下载 (推荐)
./download-wintun.sh

# 或手动下载
# 1. 访问 https://www.wintun.net/builds/wintun-0.14.1.zip
# 2. 解压到 wintun/ 目录
# 3. 确保 wintun/bin/amd64/wintun.dll 存在
```

---

## 🚀 快速开始

### Windows 用户

#### 1. 环境准备
```cmd
REM 1. 安装 Go (如果未安装)
REM 访问 https://golang.org/dl/ 下载并安装

REM 2. 克隆项目
git clone https://github.com/law52525/wireguard-go.git
cd wireguard-go

REM 3. 下载 Windows 依赖
make download-wintun
```

#### 2. 一键启动 (推荐)
```cmd
REM 以管理员身份运行命令提示符
REM 然后执行:
start.bat
```

#### 3. 手动操作
```cmd
REM 1. 编译项目
make build

REM 2. 编辑配置文件
notepad wg0.conf

REM 3. 启动服务
start.bat

REM 4. 停止服务
stop.bat

REM 5. 重启服务
restart.bat
```

**Windows 特性支持**:
- ✅ **wg-go 命令行工具**: 完全支持 Windows 命名管道通信
- ✅ **动态 DNS 监控**: 自动监控域名 IP 变化
- ✅ **日志系统**: 支持文件输出和控制台输出
- ✅ **UAPI 通信**: 使用 Windows 命名管道 (`\\.\pipe\ProtectedPrefix\Administrators\WireGuard\<interface>`)
- ✅ **管理员权限**: 自动检测并提供权限提示
- ✅ **网络配置**: 自动配置 TUN 接口 IP 地址和路由

### Windows 用户详细配置

#### 重要说明
WireGuard-Go在Windows上与官方WireGuard for Windows有一个重要区别：**不会自动配置TUN接口的IP地址和路由**。需要手动配置网络接口。

#### 1. 准备配置文件

编辑 `wg0.conf`:
```ini
[Interface]
# 生成命令: ./cmd/wg-go/wg-go.exe genkey
PrivateKey = YOUR_PRIVATE_KEY
Address = 192.168.11.35/32
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = SERVER_PUBLIC_KEY
# 支持域名，会自动解析为 IP 并监控 IP 变化
# 当域名的 IP 地址变化时，会自动重新连接
Endpoint = server.example.com:51820
AllowedIPs = 192.168.11.0/24, 192.168.10.0/24
PersistentKeepalive = 25
```

#### 2. 生成密钥对
```cmd
REM 生成私钥
cmd\wg-go\wg-go.exe genkey

REM 生成对应的公钥
echo PRIVATE_KEY | cmd\wg-go\wg-go.exe pubkey

REM 生成预共享密钥
cmd\wg-go\wg-go.exe genpsk
```

#### 3. 一键启动 (推荐)
```cmd
REM 以管理员身份运行
quick.bat
```

#### 4. 手动启动和配置
```cmd
REM 1. 启动WireGuard守护进程
wireguard-go.exe wg0

REM 2. 应用配置
cmd\wg-go\wg-go.exe setconf wg0 wg0.conf

REM 3. 手动配置网络接口 (重要!)
REM 设置接口IP地址
netsh interface ip set address "wg0" static 192.168.101.20 255.255.255.0

REM 添加路由到对等网络
route add 192.168.100.0 mask 255.255.255.0 192.168.101.20
route add 192.168.101.0 mask 255.255.255.0 192.168.101.20

REM 设置DNS服务器
netsh interface ip set dns "wg0" static 8.8.8.8
```

#### 5. 验证连接
```cmd
REM 查看连接状态
cmd\wg-go\wg-go.exe show wg0

REM 检查网络接口
ipconfig

REM 检查路由表
route print | findstr "192.168"

REM 测试连通性
ping 192.168.100.1
```

#### 6. 停止服务
```cmd
REM 自动停止 (推荐)
stop.bat

REM 手动停止
REM 停止WireGuard进程
taskkill /f /im wireguard-go.exe

REM 清理路由
route delete 192.168.100.0
route delete 192.168.101.0

REM 重置接口配置 (可选)
netsh interface ip set address "wg0" dhcp
netsh interface ip set dns "wg0" dhcp
```

**停止脚本功能**:
- ✅ **自动停止进程**: 正常停止或强制停止WireGuard进程
- ✅ **清理路由**: 自动删除对等网络路由
- ✅ **接口重置**: 可选择重置wg0接口为DHCP模式
- ✅ **状态检查**: 显示清理结果和接口状态

### Linux/macOS 用户

#### 1. 环境准备
```bash
# 1. 安装 Go (如果未安装)
# Ubuntu/Debian:
sudo apt update && sudo apt install golang-go

# CentOS/RHEL:
sudo yum install golang

# macOS (使用 Homebrew):
brew install go

# 2. 克隆项目
git clone https://github.com/law52525/wireguard-go.git
cd wireguard-go
```

#### 2. 一键启动 (推荐)
```bash
# 以管理员权限运行
sudo ./start.sh
```

#### 3. 手动操作
```bash
# 1. 编译项目
make build

# 2. 编辑配置文件
nano wg0.conf

# 3. 启动服务
sudo ./start.sh

# 4. 停止服务
sudo ./stop.sh

# 5. 重启服务
sudo ./restart.sh
```

#### 4. 生成密钥对
```bash
# 生成私钥
PRIVATE_KEY=$(./cmd/wg-go/wg-go genkey)

# 生成对应的公钥
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | ./cmd/wg-go/wg-go pubkey)

echo "私钥: $PRIVATE_KEY"
echo "公钥: $PUBLIC_KEY"
```

#### 5. 验证连接
```bash
# 查看连接状态
sudo ./cmd/wg-go/wg-go show wg0

# 测试网络连通性
ping -c 3 192.168.11.21

# 实时监控
sudo ./cmd/wg-go/wg-go monitor wg0
```

**Linux/macOS 特性支持**:
- ✅ **wg-go 命令行工具**: 完全支持 Unix socket 通信
- ✅ **动态 DNS 监控**: 自动监控域名 IP 变化
- ✅ **日志系统**: 支持文件输出和控制台输出
- ✅ **UAPI 通信**: 使用 Unix domain socket (`/var/run/wireguard/<interface>.sock`)
- ✅ **权限管理**: 自动检测并提供权限提示
- ✅ **网络配置**: 自动配置 TUN 接口 IP 地址和路由

---

## 📖 详细使用

### 配置文件详解

#### Interface 段
```ini
[Interface]
PrivateKey = base64_encoded_private_key    # 必需: 本地私钥
Address = 192.168.11.35/32                # 必需: 本地 VPN IP
ListenPort = 51820                        # 可选: 监听端口 (默认随机)
DNS = 8.8.8.8, 1.1.1.1                   # 可选: DNS 服务器
MTU = 1420                                # 可选: 最大传输单元
```

#### Peer 段
```ini
[Peer]
PublicKey = base64_encoded_public_key      # 必需: 对端公钥
Endpoint = server.com:51820               # 可选: 服务器地址 (支持域名)
AllowedIPs = 192.168.11.0/24             # 必需: 允许的 IP 范围
PresharedKey = base64_encoded_psk         # 可选: 预共享密钥
PersistentKeepalive = 25                  # 可选: 保活间隔 (秒)
```

### 网络配置详解

#### 1. 接口配置
```bash
# 配置 IP 地址 (point-to-point 接口需要相同的源和目标)
sudo ifconfig utun11 inet LOCAL_IP LOCAL_IP netmask 255.255.255.255

# 查看接口状态
ifconfig utun11
```

#### 2. 路由配置
```bash
# 添加到 VPN 网络的路由
sudo route add -net NETWORK/CIDR -interface utun11

# 示例: 添加多个网络
sudo route add -net 192.168.11.0/24 -interface utun11
sudo route add -net 192.168.10.0/24 -interface utun11

# 查看路由表
netstat -rn | grep utun11
```

#### 3. 全局 VPN (可选)
```bash
# 警告: 这会将所有流量通过 VPN，小心使用!

# 保存当前默认路由
DEFAULT_GW=$(route -n get default | grep gateway | awk '{print $2}')

# 确保 VPN 服务器不走 VPN (避免循环)
sudo route add SERVER_IP $DEFAULT_GW

# 设置 VPN 为默认路由
sudo route add -net 0.0.0.0/1 -interface utun11
sudo route add -net 128.0.0.0/1 -interface utun11
```

### 监控和调试

#### 1. 连接状态监控
```bash
# 查看详细状态
sudo ./cmd/wg-go/wg-go show utun11

# 实时监控 (默认 5 秒间隔)
sudo ./cmd/wg-go/wg-go monitor utun11

# 自定义监控间隔
sudo ./cmd/wg-go/wg-go monitor utun11 10

# 监控所有接口
sudo ./cmd/wg-go/wg-go monitor
```

#### 2. 连接测试
```bash
# 测试到 VPN 网络的连通性
ping -c 3 192.168.11.1

# 测试特定主机
ping -c 3 192.168.11.21

# 网络扫描 (如果可用)
nmap -sn 192.168.11.0/24
```

#### 3. 流量统计
```bash
# 查看数据传输统计
sudo ./cmd/wg-go/wg-go show utun11 | grep "transfer"

# 实时流量监控
watch -n 2 'sudo ./cmd/wg-go/wg-go show utun11 | grep transfer'
```

---

## 📚 命令参考

### wg-go 工具完整命令

#### 密钥管理
```bash
./cmd/wg-go/wg-go genkey                    # 生成私钥
./cmd/wg-go/wg-go genkey | ./cmd/wg-go/wg-go pubkey  # 生成密钥对
echo "PRIVATE_KEY" | ./cmd/wg-go/wg-go pubkey        # 从私钥生成公钥
./cmd/wg-go/wg-go genpsk                    # 生成预共享密钥
```

#### 配置管理
```bash
sudo ./cmd/wg-go/wg-go show                 # 显示所有接口
sudo ./cmd/wg-go/wg-go show utun11           # 显示特定接口
sudo ./cmd/wg-go/wg-go setconf utun11 wg0.conf      # 应用配置文件
sudo ./cmd/wg-go/wg-go showconf utun11       # 显示配置格式
sudo ./cmd/wg-go/wg-go addconf utun11 peer.conf     # 添加 peer
sudo ./cmd/wg-go/wg-go syncconf utun11 wg0.conf     # 同步配置
```

#### 监控功能
```bash
sudo ./cmd/wg-go/wg-go monitor              # 监控所有接口
sudo ./cmd/wg-go/wg-go monitor utun11        # 监控特定接口
sudo ./cmd/wg-go/wg-go monitor utun11 10     # 自定义更新间隔
```

#### DNS 监控管理 (新功能)
```bash
sudo ./cmd/wg-go/wg-go dns utun11 show       # 显示 DNS 监控状态
sudo ./cmd/wg-go/wg-go dns utun11 30         # 设置监控间隔为 30 秒
sudo ./cmd/wg-go/wg-go dns utun11 60         # 设置监控间隔为 60 秒
```

### 自动化脚本

#### Linux/macOS 脚本

**start.sh - 启动脚本**
```bash
sudo ./start.sh                             # 完整启动流程
```
- 检查必要文件和权限
- 停止现有连接
- 启动守护进程
- 应用配置
- 配置网络接口和路由
- 验证连接状态

**restart.sh - 重启脚本**
```bash
sudo ./restart.sh                           # 完整重启流程
```
- 停止现有 WireGuard 进程
- 清理网络配置
- 重新启动守护进程
- 重新应用配置
- 重新配置网络接口和路由

**stop.sh - 停止脚本**
```bash
sudo ./stop.sh                              # 完整停止流程
```
- 停止 WireGuard 进程
- 清理网络接口
- 清理路由表
- 清理 socket 文件
- 验证清理结果

#### Windows 脚本

**start.bat - 启动脚本**
```cmd
start.bat                                   # 完整启动流程
```
- 检查管理员权限
- 检查 Go 环境 (如需要)
- 编译可执行文件 (如需要)
- 停止现有连接
- 启动守护进程
- 应用配置
- 配置网络接口和路由
- 验证连接状态

**restart.bat - 重启脚本**
```cmd
restart.bat                                 # 完整重启流程
```
- 停止现有 WireGuard 进程
- 清理网络配置
- 重新启动守护进程
- 重新应用配置
- 重新配置网络接口和路由

**stop.bat - 停止脚本**
```cmd
stop.bat                                    # 完整停止流程
```
- 停止 WireGuard 进程
- 清理网络接口
- 清理路由表
- 清理日志文件
- 验证清理结果

### 系统命令

#### 进程管理
```bash
ps aux | grep wireguard                     # 查看 WireGuard 进程
sudo pkill wireguard-go                     # 停止 WireGuard
```

#### 网络诊断
```bash
ifconfig utun11                              # 查看接口状态
netstat -rn | grep utun11                    # 查看路由
lsof -i :51820                              # 查看端口占用
```

#### Socket 管理
```bash
ls -la /var/run/wireguard/                  # 查看 socket 文件
sudo rm /var/run/wireguard/utun11.sock       # 清理 socket 文件
```

---

## 🛠️ 故障排除

### 常见问题及解决方案

#### 1. 权限相关问题
```bash
# 问题: permission denied
# 原因: 没有使用 sudo
# 解决: 确保使用 sudo 运行需要管理员权限的命令
sudo ./cmd/wg-go/wg-go show utun11
sudo ./quick-start.sh
```

#### 2. 编译问题
```bash
# 问题: 编译失败
# 检查: Go 版本和环境
go version
go env GOOS GOARCH

# 解决: 重新编译
cd cmd/wg-go
go clean
go build -o wg-go
```

#### 3. 连接问题
```bash
# 问题: 握手失败
# 检查: 网络连通性
ping SERVER_IP
nc -u -v SERVER_IP SERVER_PORT

# 检查: 配置文件
cat wg0.conf
sudo ./cmd/wg-go/wg-go show utun11
```

#### 4. 域名解析问题
```bash
# 问题: 域名无法解析
# 检查: DNS 解析
nslookup SERVER_DOMAIN

# 临时解决: 使用 IP 地址
# 在 wg0.conf 中将 Endpoint 改为 IP:port
```

#### 5. 路由问题
```bash
# 问题: 无法访问 VPN 网络
# 检查: 路由表
netstat -rn | grep 192.168.1

# 修复: 重新添加路由
sudo route add -net 192.168.11.0/24 -interface utun11
```

### 调试技巧

#### 1. 详细日志
```bash
# 查看系统日志
sudo dmesg | grep -i wireguard
sudo log show --predicate 'process CONTAINS "wireguard"' --last 5m
```

#### 2. 网络抓包
```bash
# 抓取 WireGuard 流量 (需要安装 tcpdump)
sudo tcpdump -i utun11
sudo tcpdump -i any port 51820
```

#### 3. 逐步诊断
```bash
# 1. 检查进程
ps aux | grep wireguard

# 2. 检查接口
ifconfig utun11

# 3. 检查配置
sudo ./cmd/wg-go/wg-go show utun11

# 4. 检查路由
netstat -rn | grep utun11

# 5. 测试连通性
ping -c 1 192.168.11.21
```

---

## 🔬 技术说明

### 核心技术特性

#### 1. UAPI 协议修复
- **问题**: 官方工具的 `get=1` 命令格式不正确
- **解决**: 正确实现 `get=1\n\n` 格式
- **代码位置**: `cmd/wg-go/uapi.go`

#### 2. 智能域名解析
- **功能**: 自动将域名端点解析为 IP 地址
- **实现**: 在发送 UAPI 命令前预解析域名
- **代码位置**: `cmd/wg-go/uapi.go` 中的 `resolveEndpoint` 函数

#### 2.5. 动态 DNS 监控 (新功能)
- **功能**: 自动监控域名端点的 IP 变化，当检测到变化时自动重新连接
- **实现**: 后台定期解析域名，比较 IP 变化，自动更新端点并发起新握手
- **代码位置**: `device/dns_monitor.go` 和相关 UAPI 集成
- **监控间隔**: 默认 60 秒，可通过命令行配置 (最小 10 秒)
- **支持场景**: 动态 DNS 服务、云服务器重启、ISP 动态 IP 等

#### 3. 密钥格式转换
- **问题**: WireGuard UAPI 需要 hex 格式，但配置文件使用 base64
- **解决**: 自动进行 Base64 ↔ Hex 转换
- **代码位置**: `cmd/wg-go/crypto.go` 和 `cmd/wg-go/uapi.go`

#### 4. 超时处理
- **功能**: 防止命令挂起的智能超时机制
- **实现**: 网络连接和读取操作都有超时限制
- **配置**: 连接超时 5 秒，读取超时 10 秒

#### 5. 权限管理
- **功能**: 智能权限检查和友好提示
- **实现**: 检查 socket 目录权限，提供解决建议

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                        wg-go 工具                            │
├─────────────────────────────────────────────────────────────┤
│ main.go        │ 命令解析和分发                                │
│ commands.go    │ 各种命令的具体实现                             │
│ uapi.go        │ WireGuard UAPI 通信 + 域名解析                │
│ crypto.go      │ 密钥生成、格式转换                             │
│ monitor.go     │ 实时监控功能                                  │
└─────────────────────────────────────────────────────────────┘
                           │ UAPI Socket
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    wireguard-go 守护进程                     │
├─────────────────────────────────────────────────────────────┤
│ device/        │ WireGuard 设备管理                           │
│ conn/          │ 网络连接处理                                 │
│ tun/           │ TUN 接口管理                                 │
│ ipc/           │ UAPI 接口实现                                │
└─────────────────────────────────────────────────────────────┘
                           │ TUN Interface
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       网络栈                                 │
├─────────────────────────────────────────────────────────────┤
│ wg0/utun11 接口 │ 虚拟网络接口                                 │
│ 路由表           │ 网络路由管理                                 │
│ 防火墙           │ 网络安全策略                                 │
└─────────────────────────────────────────────────────────────┘
```

### 文件说明

#### 核心源码文件
- **main.go**: 程序入口，命令行参数解析和分发
- **commands.go**: 实现各种 WireGuard 命令功能
- **uapi.go**: WireGuard UAPI 协议通信实现
- **crypto.go**: 密钥生成、管理和格式转换
- **monitor.go**: 实时监控和状态显示功能

#### 自动化脚本
- **quick.sh**: 完整的自动启动流程
- **stop.sh**: 完整的自动停止和清理流程

### 兼容性

#### 支持的系统
- **Windows**: 完整支持，提供自动化测试 ✅
- **macOS**: 完整支持，提供自动化测试 ✅
- **Linux**: 完整支持，提供自动化测试 ✅
- **FreeBSD**: 理论支持，需要测试 🔶

#### Go 版本要求
- **最低版本**: Go 1.19
- **推荐版本**: Go 1.21+
- **测试版本**: Go 1.21.3

#### 平台特定特性

**Windows 特性**:
- ✅ **wintun.dll 支持**: 自动下载和配置
- ✅ **命名管道通信**: 使用 `\\.\pipe\ProtectedPrefix\Administrators\WireGuard\<interface>`
- ✅ **管理员权限检测**: 自动检测并提供提示
- ✅ **网络配置自动化**: 自动配置 TUN 接口和路由

**Linux/macOS 特性**:
- ✅ **Unix socket 通信**: 使用 `/var/run/wireguard/<interface>.sock`
- ✅ **TUN 接口管理**: 自动创建和配置 TUN 接口
- ✅ **权限管理**: 智能权限检查和提示
- ✅ **网络配置自动化**: 自动配置接口和路由

---

## 🎯 总结

这个 WireGuard-Go 增强版本提供了：

✅ **完整的 WireGuard 管理工具** - 无需外部依赖  
✅ **跨平台自动化脚本** - 一键启动、重启、停止 (Windows/Linux/macOS)  
✅ **智能功能** - 域名解析、动态 DNS 监控、格式转换、超时处理  
✅ **详细文档** - 从安装到故障排除的完整指南  
✅ **实战验证** - 在 Windows、macOS、Linux 上完全测试通过  
✅ **构建系统** - Makefile 和构建脚本支持多平台编译  
✅ **Windows 支持** - 完整的 Windows 支持，包括 wintun.dll 自动配置  

现在您可以享受一个功能完整、易于使用、跨平台的 WireGuard VPN 解决方案！

---

**需要帮助？** 

**Windows 用户:**
- 运行 `wg-go.exe help` 查看命令帮助
- 使用 `start.bat` 快速开始

**Linux/macOS 用户:**
- 运行 `wg-go help` 查看命令帮助
- 使用 `sudo ./start.sh` 快速开始
