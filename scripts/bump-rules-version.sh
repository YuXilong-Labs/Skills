#!/bin/bash
# bump-rules-version.sh — ios-dev-rules 版本号同步工具
# 用法:
#   ./scripts/bump-rules-version.sh <new-version>   同步两处 version
#   ./scripts/bump-rules-version.sh --check          检查两处是否一致

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLUGIN_JSON="$REPO_ROOT/plugins/ios-dev-rules/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 从 plugin.json 读版本（文件只有一个 version 字段）
get_plugin_version() {
    grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PLUGIN_JSON" | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}

# 从 marketplace.json 读 ios-dev-rules 条目的版本（用 awk 精确定位）
get_market_version() {
    awk '
        /"name"[[:space:]]*:[[:space:]]*"ios-dev-rules"/ { in_block=1 }
        in_block && /"version"[[:space:]]*:/ {
            line = $0
            gsub(/.*"version"[[:space:]]*:[[:space:]]*"/, "", line)
            gsub(/".*/, "", line)
            print line
            exit
        }
    ' "$MARKETPLACE_JSON"
}

if [ "${1:-}" = "--check" ]; then
    plugin_ver=$(get_plugin_version)
    market_ver=$(get_market_version)

    echo "plugin.json:      $plugin_ver"
    echo "marketplace.json: $market_ver"

    if [ "$plugin_ver" != "$market_ver" ]; then
        echo -e "${RED}✗ 版本号不一致！请运行: ./scripts/bump-rules-version.sh <version>${NC}"
        exit 1
    fi

    # 检查 rules/ 是否有未 bump 的改动（staged 或 unstaged）
    if git -C "$REPO_ROOT" diff --name-only 2>/dev/null | grep -q "plugins/ios-dev-rules/rules/" || \
       git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null | grep -q "plugins/ios-dev-rules/rules/"; then
        if ! git -C "$REPO_ROOT" diff --name-only 2>/dev/null | grep -q "plugins/ios-dev-rules/.claude-plugin/plugin.json" && \
           ! git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null | grep -q "plugins/ios-dev-rules/.claude-plugin/plugin.json"; then
            echo -e "${YELLOW}⚠ rules/ 有改动但 plugin.json 版本未 bump，请运行: ./scripts/bump-rules-version.sh <new-version>${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}✓ 版本号一致: $plugin_ver${NC}"
    exit 0
fi

NEW_VERSION="${1:-}"
if [ -z "$NEW_VERSION" ]; then
    echo "用法: $0 <new-version> | --check"
    exit 1
fi

# 更新 plugin.json（文件内唯一的 version 字段）
sed -i.bak "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON" && rm -f "${PLUGIN_JSON}.bak"

# 更新 marketplace.json 中 ios-dev-rules 条目的 version（awk 精确替换）
awk -v ver="$NEW_VERSION" '
    /"name"[[:space:]]*:[[:space:]]*"ios-dev-rules"/ { in_block=1 }
    in_block && /"version"[[:space:]]*:/ {
        sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" ver "\"")
        in_block=0
    }
    { print }
' "$MARKETPLACE_JSON" > "${MARKETPLACE_JSON}.tmp" && mv "${MARKETPLACE_JSON}.tmp" "$MARKETPLACE_JSON"

plugin_ver=$(get_plugin_version)
market_ver=$(get_market_version)

echo -e "${GREEN}✓ plugin.json      → $plugin_ver${NC}"
echo -e "${GREEN}✓ marketplace.json → $market_ver${NC}"
