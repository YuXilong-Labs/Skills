#!/bin/bash
# check-update.sh — ios-dev-rules 远端版本检测
# Created by yuxilong on 2026/04/28

set -e

REPO_RAW="https://raw.githubusercontent.com/YuXilong-Labs/Skills/main"
PLUGIN_JSON_URL="$REPO_RAW/plugins/ios-dev-rules/.claude-plugin/plugin.json"
LOCAL_VERSION_FILE="$HOME/.claude/rules/ios-dev-rules.version"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE" 2>/dev/null || echo "0.0.0")

REMOTE_JSON=$(curl -fsSL --max-time 5 "$PLUGIN_JSON_URL" 2>/dev/null || true)
if [ -z "$REMOTE_JSON" ]; then
    echo -e "${YELLOW}⚠ 无法获取远端版本（网络异常或仓库不可达），跳过检测${NC}"
    echo -e "  当前版本: ${CYAN}$LOCAL_VERSION${NC}"
    exit 0
fi

REMOTE_VERSION=$(echo "$REMOTE_JSON" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$REMOTE_VERSION" ]; then
    echo -e "${YELLOW}⚠ 解析远端版本失败${NC}"
    exit 0
fi

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}✓ ios-dev-rules 已是最新版本: ${CYAN}$LOCAL_VERSION${NC}"
else
    echo -e "${YELLOW}⚡ 发现新版本: ${CYAN}$LOCAL_VERSION${NC} → ${GREEN}$REMOTE_VERSION${NC}"
    echo -e "  运行以下命令升级:"
    echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash -s -- ios-dev-rules${NC}"
fi
