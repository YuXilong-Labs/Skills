#!/bin/bash
# install.sh — Skills 仓库统一安装脚本
# Created by yuxilong on 2026/03/13

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Skills Installer for Claude Code   ║${NC}"
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
}

list_skills() {
    echo -e "${BLUE}可用 Skills:${NC}"
    echo
    if [ -d "$SCRIPT_DIR/skills" ]; then
        for skill_dir in "$SCRIPT_DIR/skills"/*/; do
            if [ -d "$skill_dir" ]; then
                skill_name=$(basename "$skill_dir")
                if [ -f "$skill_dir/SKILL.md" ]; then
                    # 从 SKILL.md 的 frontmatter 提取 description 第一行
                    desc=$(sed -n '/^description:/,/^[^ ]/{ /^description:/{ s/^description:\s*//; /|/!p; }; /^  /{ s/^  //; p; q; }; }' "$skill_dir/SKILL.md" 2>/dev/null | head -1)
                    echo -e "  ${GREEN}●${NC} ${skill_name}"
                    [ -n "$desc" ] && echo -e "    ${YELLOW}${desc}${NC}"
                else
                    echo -e "  ${RED}○${NC} ${skill_name} (缺少 SKILL.md)"
                fi
            fi
        done
    else
        echo -e "  ${RED}未找到 skills/ 目录${NC}"
    fi
    echo
}

install_skill() {
    local skill_name="$1"
    local skill_src="$SCRIPT_DIR/skills/$skill_name"
    local skill_dst="$SKILLS_DIR/$skill_name"
    local cmd_src="$SCRIPT_DIR/commands/${skill_name}.md"
    local cmd_dst="$COMMANDS_DIR/${skill_name}.md"

    # 检查源目录
    if [ ! -d "$skill_src" ]; then
        echo -e "${RED}✗ Skill '$skill_name' 不存在${NC}"
        return 1
    fi

    # 检查是否已安装
    if [ -d "$skill_dst" ]; then
        echo -e "${YELLOW}⚠ Skill '$skill_name' 已安装，将覆盖更新${NC}"
    fi

    # 创建目标目录
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$COMMANDS_DIR"

    # 复制 skill 目录
    cp -r "$skill_src" "$skill_dst"
    echo -e "${GREEN}✓${NC} 已安装 skill: ${CYAN}$skill_dst${NC}"

    # 复制 command 文件（如果存在）
    if [ -f "$cmd_src" ]; then
        cp "$cmd_src" "$cmd_dst"
        echo -e "${GREEN}✓${NC} 已安装 command: ${CYAN}$cmd_dst${NC}"
    fi
}

uninstall_skill() {
    local skill_name="$1"
    local skill_dst="$SKILLS_DIR/$skill_name"
    local cmd_dst="$COMMANDS_DIR/${skill_name}.md"
    local removed=false

    if [ -d "$skill_dst" ]; then
        rm -rf "$skill_dst"
        echo -e "${GREEN}✓${NC} 已卸载 skill: ${CYAN}$skill_dst${NC}"
        removed=true
    fi

    if [ -f "$cmd_dst" ]; then
        rm "$cmd_dst"
        echo -e "${GREEN}✓${NC} 已卸载 command: ${CYAN}$cmd_dst${NC}"
        removed=true
    fi

    if [ "$removed" = false ]; then
        echo -e "${YELLOW}⚠ Skill '$skill_name' 未安装${NC}"
    fi
}

install_all() {
    echo -e "${BLUE}安装所有 Skills...${NC}"
    echo

    local count=0
    if [ -d "$SCRIPT_DIR/skills" ]; then
        for skill_dir in "$SCRIPT_DIR/skills"/*/; do
            if [ -d "$skill_dir" ]; then
                skill_name=$(basename "$skill_dir")
                install_skill "$skill_name"
                count=$((count + 1))
                echo
            fi
        done
    fi

    if [ $count -eq 0 ]; then
        echo -e "${RED}未找到任何 Skill${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ 共安装 ${count} 个 Skill${NC}"
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
