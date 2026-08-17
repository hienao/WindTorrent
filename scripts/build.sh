#!/bin/bash
#===========================================
# WindWalker 构建脚本
# 用于构建上传 Google Play 所需的 App Bundle
#===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/build/outputs"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  WindWalker 构建脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 进入项目目录
cd "$PROJECT_DIR"

# 清理旧构建
echo -e "\n${YELLOW}[1/3] 清理旧构建...${NC}"
flutter clean

# 获取依赖
echo -e "\n${YELLOW}[2/3] 获取依赖...${NC}"
flutter pub get

# 构建 App Bundle (Google Play 上架用)
echo -e "\n${YELLOW}[3/3] 构建 App Bundle...${NC}"
flutter build appbundle --release

# 输出结果
BUNDLE_PATH="$OUTPUT_DIR/app/outputs/bundle/release/app-release.aab"
if [ -f "$BUNDLE_PATH" ]; then
    echo -e "\n${GREEN}✅ 构建成功！${NC}"
    echo -e "App Bundle 路径: ${YELLOW}$BUNDLE_PATH${NC}"
    echo -e "文件大小: $(du -h "$BUNDLE_PATH" | cut -f1)"
else
    # 尝试查找实际路径
    FOUND=$(find "$OUTPUT_DIR" -name "*.aab" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        echo -e "\n${GREEN}✅ 构建成功！${NC}"
        echo -e "App Bundle 路径: ${YELLOW}$FOUND${NC}"
        echo -e "文件大小: $(du -h "$FOUND" | cut -f1)"
    else
        echo -e "\n${RED}❌ 构建失败：未找到 .aab 文件${NC}"
        exit 1
    fi
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "下一步（自动上传 Internal Testing）："
echo -e "${YELLOW}cd android && ./gradlew :app:publishReleaseBundle${NC}"
echo -e "如需手动上传：登录 Google Play Console 上传 .aab 文件"
echo -e "========================================${NC}"
