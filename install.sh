#!/bin/bash
# install.sh — Skills 仓库统一安装脚本
# Created by yuxilong on 2026/03/13
# 支持双目标安装（Claude Code + Codex）和 curl 远程安装

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://github.com/YuXilong-Labs/Skills.git"
TARGETS=("$HOME/.claude" "$HOME/.codex")
CLEANUP=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# curl 远程安装：如果当前目录没有 plugins/ 目录，自动 clone
if [ ! -d "$SCRIPT_DIR/plugins" ]; then
    echo -e "${BLUE}未检测到本地仓库，从远程 clone...${NC}"
    TMPDIR=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$TMPDIR/Skills" 2>/dev/null
    SCRIPT_DIR="$TMPDIR/Skills"
    CLEANUP=true
fi

cleanup() {
    if [ "$CLEANUP" = true ] && [ -n "${TMPDIR:-}" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Skills Installer for Claude Code   ║${NC}"
    echo -e "${CYAN}║         & OpenAI Codex CLI           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo
}

print_usage() {
    echo -e "${BLUE}用法:${NC}"
    echo "  ./install.sh                     安装所有 Skills"
    echo "  ./install.sh <skill-name>        安装指定 Skill"
    echo "  ./install.sh --uninstall <name>  卸载指定 Skill"
    echo "  ./install.sh --list              列出所有可用 Skills"
    echo "  ./install.sh --help              显示帮助信息"
    echo
    echo -e "${BLUE}远程安装:${NC}"
    echo "  curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash"
    echo
}

list_skills() {
    echo -e "${BLUE}可用 Skills:${NC}"
    echo
    if [ -d "$SCRIPT_DIR/plugins" ]; then
        for plugin_dir in "$SCRIPT_DIR/plugins"/*/; do
            if [ -d "$plugin_dir" ]; then
                plugin_name=$(basename "$plugin_dir")
                # 在 plugin 子目录中找 SKILL.md
                skill_md=$(find "$plugin_dir/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null | head -1)
                if [ -n "$skill_md" ] && [ -f "$skill_md" ]; then
                    desc=$(sed -n '/^description:/,/^[^ ]/{ /^description:/{ s/^description:\s*//; /|/!p; }; /^  /{ s/^  //; p; q; }; }' "$skill_md" 2>/dev/null | head -1)
                    echo -e "  ${GREEN}●${NC} ${plugin_name}"
                    [ -n "$desc" ] && echo -e "    ${YELLOW}${desc}${NC}"
                else
                    echo -e "  ${RED}○${NC} ${plugin_name} (缺少 SKILL.md)"
                fi
            fi
        done
    else
        echo -e "  ${RED}未找到 plugins/ 目录${NC}"
    fi
    echo
}

install_skill() {
    local plugin_name="$1"
    local plugin_dir="$SCRIPT_DIR/plugins/$plugin_name"

    if [ ! -d "$plugin_dir" ]; then
        echo -e "${RED}✗ Skill '$plugin_name' 不存在${NC}"
        return 1
    fi

    for target in "${TARGETS[@]}"; do
        local target_name
        target_name=$(basename "$target")
        local skills_dst="$target/skills"
        local commands_dst="$target/commands"

        mkdir -p "$skills_dst"
        mkdir -p "$commands_dst"

        # 复制 skills/ 子目录
        if [ -d "$plugin_dir/skills" ]; then
            cp -r "$plugin_dir/skills/"* "$skills_dst/"
            echo -e "${GREEN}✓${NC} [${target_name}] 已安装 skill: ${CYAN}$skills_dst/$plugin_name${NC}"
        fi

        # 复制 commands/ 文件
        if [ -d "$plugin_dir/commands" ]; then
            cp "$plugin_dir/commands/"* "$commands_dst/"
            echo -e "${GREEN}✓${NC} [${target_name}] 已安装 command: ${CYAN}$commands_dst/${plugin_name}.md${NC}"
        fi
    done
}

uninstall_skill() {
    local plugin_name="$1"
    local removed=false

    for target in "${TARGETS[@]}"; do
        local target_name
        target_name=$(basename "$target")
        local skill_dst="$target/skills/$plugin_name"
        local cmd_dst="$target/commands/${plugin_name}.md"

        if [ -d "$skill_dst" ]; then
            rm -rf "$skill_dst"
            echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 skill: ${CYAN}$skill_dst${NC}"
            removed=true
        fi

        if [ -f "$cmd_dst" ]; then
            rm "$cmd_dst"
            echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 command: ${CYAN}$cmd_dst${NC}"
            removed=true
        fi
    done

    if [ "$removed" = false ]; then
        echo -e "${YELLOW}⚠ Skill '$plugin_name' 未安装${NC}"
    fi
}

install_all() {
    echo -e "${BLUE}安装所有 Skills...${NC}"
    echo

    local count=0
    if [ -d "$SCRIPT_DIR/plugins" ]; then
        for plugin_dir in "$SCRIPT_DIR/plugins"/*/; do
            if [ -d "$plugin_dir" ]; then
                plugin_name=$(basename "$plugin_dir")
                install_skill "$plugin_name"
                count=$((count + 1))
                echo
            fi
        done
    fi

    if [ $count -eq 0 ]; then
        echo -e "${RED}未找到任何 Skill${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ 共安装 ${count} 个 Skill（目标：${TARGETS[*]}）${NC}"
}

# --- 主逻辑 ---

print_header

case "${1:-}" in
    --help|-h)
        print_usage
        ;;
    --list|-l)
        list_skills
        ;;
    --uninstall|-u)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}请指定要卸载的 Skill 名称${NC}"
            echo
            print_usage
            exit 1
        fi
        uninstall_skill "$2"
        ;;
    "")
        install_all
        ;;
    *)
        install_skill "$1"
        ;;
esac
