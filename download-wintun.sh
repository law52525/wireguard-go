#!/bin/bash
# Download wintun.dll for Windows development

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📥 Downloading wintun.dll for Windows development...${NC}"

# Create wintun directory
mkdir -p wintun

# Download wintun-0.14.1.zip
echo "Downloading wintun-0.14.1.zip..."
curl -L -o wintun/wintun-0.14.1.zip https://www.wintun.net/builds/wintun-0.14.1.zip

# Extract all architectures
echo "Extracting wintun.dll for all architectures..."
cd wintun
unzip -o wintun-0.14.1.zip

# Verify extraction
if [ -d "wintun/bin" ]; then
    echo -e "${GREEN}✅ wintun.dll extracted successfully${NC}"
    echo "Available architectures:"
    ls -la wintun/bin/
    
    echo
    echo -e "${YELLOW}📋 wintun.dll files:${NC}"
    find wintun/bin -name "wintun.dll" -exec ls -la {} \;
    
    echo
    echo -e "${GREEN}🎉 wintun.dll ready for Windows development!${NC}"
    echo "Architecture mapping:"
    echo "  - amd64: wintun/bin/amd64/wintun.dll"
    echo "  - arm64: wintun/bin/arm64/wintun.dll"
    echo "  - 386:   wintun/bin/x86/wintun.dll"
    echo "  - arm:   wintun/bin/arm/wintun.dll"
else
    echo -e "${RED}❌ Failed to extract wintun.dll${NC}"
    exit 1
fi
