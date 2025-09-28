# WireGuard-Go Makefile
# 支持跨平台编译

.PHONY: all build build-linux build-windows build-macos clean test download-wintun

# 默认目标
all: build

# 检测操作系统
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    OS := linux
    TARGET := wireguard-go
    MAIN_FILE := main.go
endif
ifeq ($(UNAME_S),Darwin)
    OS := darwin
    TARGET := wireguard-go
    MAIN_FILE := main.go
endif
ifeq ($(OS),Windows_NT)
    OS := windows
    TARGET := wireguard-go.exe
    MAIN_FILE := main_windows.go
endif

# 构建目标
build:
	@echo "🔨 Building for $(OS)..."
	@go build -o $(TARGET) .
	@if [ "$(OS)" = "windows" ] && [ -f "wintun/wintun/bin/amd64/wintun.dll" ]; then \
		echo "📦 Copying wintun.dll..."; \
		cp wintun/wintun/bin/amd64/wintun.dll .; \
	fi
	@echo "✅ Build completed: $(TARGET)"

# Linux 构建
build-linux:
	@echo "🐧 Building for Linux..."
	@GOOS=linux GOARCH=amd64 go build -o wireguard-go-linux .
	@echo "✅ Linux build completed: wireguard-go-linux"

# Windows 构建
build-windows:
	@echo "🪟 Building for Windows..."
	@GOOS=windows GOARCH=amd64 go build -o wireguard-go-windows.exe .
	@if [ -f "wintun/wintun/bin/amd64/wintun.dll" ]; then \
		echo "📦 Copying wintun.dll for amd64..."; \
		cp wintun/wintun/bin/amd64/wintun.dll .; \
	fi
	@echo "✅ Windows build completed: wireguard-go-windows.exe"

# macOS 构建
build-macos:
	@echo "🍎 Building for macOS..."
	@GOOS=darwin GOARCH=amd64 go build -o wireguard-go-macos .
	@echo "✅ macOS build completed: wireguard-go-macos"

# 构建命令行工具
build-tools:
	@echo "🔧 Building command line tools..."
	@cd cmd/wg-go && go build -o wg-go .
	@if [ "$(OS)" = "windows" ]; then \
		cd cmd/wg-go && go build -o wg-go.exe .; \
	fi
	@echo "✅ Command line tools built"

# 构建所有平台
build-all: build-linux build-windows build-macos build-tools
	@echo "🎉 All platforms built successfully!"

# 清理
clean:
	@echo "🧹 Cleaning up..."
	@rm -f wireguard-go wireguard-go.exe
	@rm -f wireguard-go-linux wireguard-go-windows.exe wireguard-go-macos
	@rm -f cmd/wg-go/wg-go cmd/wg-go/wg-go.exe
	@rm -f *.log
	@echo "✅ Cleanup completed"

# 测试
test:
	@echo "🧪 Running tests..."
	@go test ./...
	@echo "✅ Tests completed"

# 安装依赖
deps:
	@echo "📦 Installing dependencies..."
	@go mod tidy
	@go mod download
	@echo "✅ Dependencies installed"

# 下载 wintun.dll
download-wintun:
	@echo "📥 Downloading wintun.dll for Windows development..."
	@./download-wintun.sh

# 帮助
help:
	@echo "WireGuard-Go Build System"
	@echo "========================"
	@echo "Available targets:"
	@echo "  build            - Build for current platform"
	@echo "  build-linux      - Build for Linux"
	@echo "  build-windows    - Build for Windows"
	@echo "  build-macos      - Build for macOS"
	@echo "  build-all        - Build for all platforms"
	@echo "  build-tools      - Build command line tools"
	@echo "  download-wintun  - Download wintun.dll for Windows"
	@echo "  clean            - Clean build artifacts"
	@echo "  test             - Run tests"
	@echo "  deps             - Install dependencies"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Current platform: $(OS)"
	@echo "Target file: $(TARGET)"
	@echo "Main file: $(MAIN_FILE)"