#!/bin/bash
# check-and-upgrade.sh — ios-dev-rules 版本检测与自动升级
# 用法:
#   check-and-upgrade.sh [--mode=check|auto|force] [--target=claude|codex]
#
#   --mode=check  (默认) 打印本地/远端版本对比
#   --mode=auto   节流检测 + 后台异步升级（每日一次）
#   --mode=force  阻塞立即升级（/ios-dev-rules update 专用）
#   --target=claude|codex  (默认 claude)

MODE="check"
TARGET="claude"

for arg in "$@"; do
    case "$arg" in
        --mode=*) MODE="${arg#--mode=}" ;;
        --target=*) TARGET="${arg#--target=}" ;;
    esac
done

REPO_RAW="https://raw.githubusercontent.com/YuXilong-Labs/Skills/main"
PLUGIN_JSON_URL="$REPO_RAW/plugins/ios-dev-rules/.claude-plugin/plugin.json"
INSTALL_URL="$REPO_RAW/install.sh"

TARGET_DIR="$HOME/.$TARGET"
VERSION_FILE="$TARGET_DIR/rules/ios-dev-rules.version"
LAST_CHECK_FILE="$TARGET_DIR/rules/.ios-dev-rules.last-check"
UPGRADE_LOG="$TARGET_DIR/rules/.ios-dev-rules.upgrade.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

fetch_remote_version() {
    local json
    json=$(curl -fsSL --max-time 5 "$PLUGIN_JSON_URL" 2>/dev/null) || return 1
    echo "$json" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}

get_local_version() {
    cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0"
}

# ── mode=auto ──────────────────────────────────────────────────────────────
if [ "$MODE" = "auto" ]; then
    # 节流：last-check 文件存在且 mtime < 86400s 则跳过
    if [ -f "$LAST_CHECK_FILE" ]; then
        last_ts=$(stat -f "%m" "$LAST_CHECK_FILE" 2>/dev/null || stat -c "%Y" "$LAST_CHECK_FILE" 2>/dev/null || echo 0)
        now_ts=$(date +%s)
        if [ $((now_ts - last_ts)) -lt 86400 ]; then
            exit 0
        fi
    fi

    # 更新时间戳（无论后续是否需要升级，都刷新，避免网络慢时重复触发）
    touch "$LAST_CHECK_FILE" 2>/dev/null || true

    # 静默获取远端版本，任何失败都 exit 0
    REMOTE_VERSION=$(fetch_remote_version 2>/dev/null) || exit 0
    [ -z "$REMOTE_VERSION" ] && exit 0

    LOCAL_VERSION=$(get_local_version)
    [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ] && exit 0

    # 版本不同 → 后台异步升级
    LOG_ENTRY="[$(date '+%Y-%m-%d %H:%M:%S')] $LOCAL_VERSION → $REMOTE_VERSION"
    {
        echo "$LOG_ENTRY" >> "$UPGRADE_LOG"
        curl -fsSL --max-time 30 "$INSTALL_URL" | bash -s -- ios-dev-rules >> "$UPGRADE_LOG" 2>&1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] upgrade done" >> "$UPGRADE_LOG"
    } &
    disown 2>/dev/null || true
    exit 0
fi

# ── mode=force ─────────────────────────────────────────────────────────────
if [ "$MODE" = "force" ]; then
    REMOTE_VERSION=$(fetch_remote_version) || {
        echo -e "${YELLOW}⚠ 无法获取远端版本（网络异常），跳过升级${NC}"
        exit 0
    }
    [ -z "$REMOTE_VERSION" ] && { echo -e "${YELLOW}⚠ 解析远端版本失败${NC}"; exit 0; }

    LOCAL_VERSION=$(get_local_version)

    if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}✓ ios-dev-rules 已是最新版本: ${CYAN}$LOCAL_VERSION${NC}"
        exit 0
    fi

    echo -e "${YELLOW}⚡ 发现新版本: ${CYAN}$LOCAL_VERSION${NC} → ${GREEN}$REMOTE_VERSION${NC}"
    echo -e "  正在升级..."
    curl -fsSL "$INSTALL_URL" | bash -s -- ios-dev-rules
    touch "$LAST_CHECK_FILE" 2>/dev/null || true
    exit 0
fi

# ── mode=check (default) ───────────────────────────────────────────────────
REMOTE_VERSION=$(fetch_remote_version) || {
    echo -e "${YELLOW}⚠ 无法获取远端版本（网络异常或仓库不可达），跳过检测${NC}"
    LOCAL_VERSION=$(get_local_version)
    echo -e "  当前版本: ${CYAN}$LOCAL_VERSION${NC}"
    exit 0
}
[ -z "$REMOTE_VERSION" ] && { echo -e "${YELLOW}⚠ 解析远端版本失败${NC}"; exit 0; }

LOCAL_VERSION=$(get_local_version)

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}✓ ios-dev-rules 已是最新版本: ${CYAN}$LOCAL_VERSION${NC}"
else
    echo -e "${YELLOW}⚡ 发现新版本: ${CYAN}$LOCAL_VERSION${NC} → ${GREEN}$REMOTE_VERSION${NC}"
    echo -e "  运行以下命令立即升级:"
    echo -e "  ${CYAN}/ios-dev-rules update${NC}"
fi
