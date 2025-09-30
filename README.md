# 🔧 WireGuard-Go 使用指南

> 基于官方 WireGuard-Go 的增强实现，包含自制管理工具和跨平台自动化脚本

### 特色功能
- **🔧 wg-go 管理工具**: 自制的 Go 版本 WireGuard 管理工具
- **🚀 跨平台自动化脚本**: 一键启动、重启、停止脚本 (支持 Windows/Linux/
macOS)
- **🌐 智能域名解析**: 自动将域名解析为 IP 地址
- **🔄 动态 DNS 监控**: 自动监控域名端点的 IP 变化并重新连接
- **🔑 智能密钥转换**: Base64 ↔ Hex 格式自动转换
- **📊 实时监控**: 连接状态和流量统计的实时监控
- **🖥️ 跨平台支持**: 完整支持 Windows、Linux、macOS
- **📦 构建系统**: 跨平台构建脚本支持多平台编译

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

## 🚀 快速开始

### Windows 用户
```cmd
# 1. 克隆项目
git clone https://github.com/law52525/wireguard-go.git
cd wireguard-go

# 2. 下载依赖 (仅 Windows)
download-wintun.bat

# 3. 编译项目
build.bat build
bulid.bat build-tools

# 4. 编辑配置
notepad wg0.conf

# 5. 一键启动
start.bat
```

### Linux/macOS 用户
```bash
# 1. 克隆项目
git clone https://github.com/law52525/wireguard-go.git
cd wireguard-go

# 2. 编译项目
./build.sh build
./bulid.sh build-tools

# 3. 编辑配置
nano wg0.conf

# 3. 一键启动
sudo ./start.sh
```

💡 **提示**: 如果不想自己编译，可以从 [Releases](https://github.com/law52525/wireguard-go/releases) 下载预编译的可执行文件，支持 Windows、Linux、macOS 的各个架构版本，开箱即用！

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
│   └── download-wintun.bat       # Windows wintun.dll 下载脚本
│
├── 📚 文档
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

## ⭐ 核心功能

### 1. wg-go 管理工具
- **密钥管理**: 生成、转换密钥格式
- **配置管理**: 应用、查看、同步配置
- **实时监控**: 连接状态和流量统计
- **DNS 监控**: 自动监控域名 IP 变化

### 2. 跨平台自动化
- **一键启动**: 自动编译、配置、启动
- **智能重启**: 自动停止、清理、重启
- **完整停止**: 自动清理所有资源

### 3. 智能特性
- **域名解析**: 自动解析域名端点
- **动态 DNS**: 监控 IP 变化并自动重连
- **格式转换**: Base64 ↔ Hex 自动转换
- **超时处理**: 防止命令挂起

## 📖 详细使用

### 配置文件示例

**wg0.conf:**
```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 192.168.2.10/32
DNS = 8.8.8.8

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = server.example.com:51820  # 支持域名
AllowedIPs = 192.168.2.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

### 密钥生成
```bash
# Linux/macOS
PRIVATE_KEY=$(./cmd/wg-go/wg-go genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | ./cmd/wg-go/wg-go pubkey)

# Windows
cmd\wg-go\wg-go.exe genkey
echo PRIVATE_KEY | cmd\wg-go\wg-go.exe pubkey
```

### 常用命令

#### 配置管理
```bash
# 查看状态
sudo ./cmd/wg-go/wg-go show wg0

# 应用配置
sudo ./cmd/wg-go/wg-go setconf wg0 wg0.conf

# 查看配置
sudo ./cmd/wg-go/wg-go showconf wg0
```

#### 监控功能
```bash
# 实时监控
sudo ./cmd/wg-go/wg-go monitor wg0

# DNS 监控管理
sudo ./cmd/wg-go/wg-go dns wg0 show      # 查看状态
sudo ./cmd/wg-go/wg-go dns wg0 30        # 设置 30 秒间隔
```

#### 自动化脚本
```bash
# Linux/macOS
sudo ./start.sh      # 启动
sudo ./restart.sh    # 重启
sudo ./stop.sh       # 停止

# Windows
start.bat            # 启动
restart.bat          # 重启
stop.bat             # 停止
```

## 🔨 构建和编译

### 使用构建脚本 (推荐)
```bash
# Linux/macOS
./build.sh build          # 构建当前平台
./build.sh build-all      # 构建所有平台
./build.sh build-tools    # 构建命令行工具
./build.sh clean          # 清理

# Windows
build.bat build           # 构建当前平台
build.bat build-all       # 构建所有平台
build.bat build-tools     # 构建命令行工具
build.bat clean           # 清理
```

### 手动编译
```bash
# Linux/macOS
go build -o wireguard-go .
cd cmd/wg-go && go build -o wg-go .

# Windows
go build -o wireguard-go.exe .
cd cmd\wg-go && go build -o wg-go.exe .
```

## 🛠️ 故障排除

### 常见问题

#### 1. 权限问题
```bash
# 问题: permission denied
# 解决: 使用 sudo
sudo ./cmd/wg-go/wg-go show wg0
```

#### 2. 连接问题
```bash
# 检查状态
sudo ./cmd/wg-go/wg-go show wg0

# 检查网络
ping 192.168.2.1

# 检查路由
netstat -rn | grep wg0
```

#### 3. 编译问题
```bash
# 检查 Go 版本
go version

# 清理重编译
go clean
go build -o wireguard-go .
```

### 调试技巧
```bash
# 查看进程
ps aux | grep wireguard

# 查看接口
ifconfig wg0

# 查看日志
sudo dmesg | grep -i wireguard
```

## 🔬 技术特性

### 核心改进
1. **UAPI 协议修复**: 正确实现 `get=1\n\n` 格式
2. **智能域名解析**: 自动解析域名端点
3. **动态 DNS 监控**: 自动监控 IP 变化并重连
4. **密钥格式转换**: Base64 ↔ Hex 自动转换
5. **超时处理**: 防止命令挂起

### 平台支持
- **Windows**: 完整支持，需要 wintun.dll
- **Linux**: 完整支持，使用 Unix socket
- **macOS**: 完整支持，使用 Unix socket

### 架构图
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

## 📚 命令参考

### wg-go 工具命令
```bash
# 密钥管理
wg-go genkey                    # 生成私钥
echo "KEY" | wg-go pubkey       # 生成公钥
wg-go genpsk                    # 生成预共享密钥

# 配置管理
wg-go show [interface]          # 显示状态
wg-go setconf <interface> <config>  # 应用配置
wg-go showconf <interface>      # 显示配置

# 监控功能
wg-go monitor [interface] [interval]  # 实时监控
wg-go dns <interface> show      # DNS 监控状态
wg-go dns <interface> <interval>  # 设置监控间隔
```

---

## 🎯 总结

这个 WireGuard-Go 增强版本提供：

✅ **完整的 WireGuard 管理工具** - 无需外部依赖  
✅ **跨平台自动化脚本** - 一键启动、重启、停止  
✅ **智能功能** - 域名解析、动态 DNS 监控、格式转换  
✅ **详细文档** - 从安装到故障排除的完整指南  
✅ **实战验证** - 在 Windows、macOS、Linux 上完全测试通过  

**快速开始:**
- Windows: `start.bat`
- Linux/macOS: `sudo ./start.sh`

**需要帮助？** 运行 `wg-go help` 查看命令帮助