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
                elif [ -d "$plugin_dir/hooks" ]; then
                    # Hook 类 plugin（无 SKILL.md，有 hooks/ 目录）
                    hook_desc=""
                    if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
                        hook_desc=$(sed -n 's/.*"description":\s*"\(.*\)".*/\1/p' "$plugin_dir/.claude-plugin/plugin.json" 2>/dev/null | head -1)
                    fi
                    echo -e "  ${BLUE}⚡${NC} ${plugin_name} ${CYAN}(Hook)${NC}"
                    [ -n "$hook_desc" ] && echo -e "    ${YELLOW}${hook_desc}${NC}"
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

        # 复制 agents/ 文件（Codex agent 配置）
        if [ -d "$plugin_dir/agents" ]; then
            local agents_dst="$target/agents"
            mkdir -p "$agents_dst"
            cp -r "$plugin_dir/agents/"* "$agents_dst/"
            echo -e "${GREEN}✓${NC} [${target_name}] 已安装 agent: ${CYAN}$agents_dst/${NC}"
        fi
    done

    # Hook 配置提示（需手动或自动合并到 settings.json）
    if [ -f "$plugin_dir/hooks/settings-snippet.json" ]; then
        local claude_settings="$HOME/.claude/settings.json"
        echo
        echo -e "${YELLOW}⚡ Hook 配置需合并到 Claude Code settings:${NC}"
        if command -v jq >/dev/null 2>&1 && [ -f "$claude_settings" ]; then
            # 自动合并 hook 配置
            local snippet="$plugin_dir/hooks/settings-snippet.json"
            local hooks_to_add
            hooks_to_add=$(jq '.hooks.PostToolUse // []' "$snippet" 2>/dev/null)
            if [ -n "$hooks_to_add" ] && [ "$hooks_to_add" != "[]" ]; then
                local existing_hooks
                existing_hooks=$(jq '.hooks.PostToolUse // []' "$claude_settings" 2>/dev/null)
                # 检查是否已包含该 hook（通过 statusMessage 判断）
                local status_msg
                status_msg=$(jq -r '.[0].hooks[0].statusMessage // empty' <<< "$hooks_to_add" 2>/dev/null)
                local already_exists
                already_exists=$(jq --arg msg "$status_msg" '[.hooks.PostToolUse[]?.hooks[]? | select(.statusMessage == $msg)] | length' "$claude_settings" 2>/dev/null)
                if [ "${already_exists:-0}" -gt 0 ]; then
                    echo -e "  ${GREEN}✓${NC} Hook 已存在于 settings.json，无需重复添加"
                else
                    jq --argjson newhooks "$hooks_to_add" '.hooks.PostToolUse = (.hooks.PostToolUse // []) + $newhooks' "$claude_settings" > "${claude_settings}.tmp" \
                        && mv "${claude_settings}.tmp" "$claude_settings" \
                        && echo -e "  ${GREEN}✓${NC} 已自动合并 Hook 配置到 ${CYAN}$claude_settings${NC}" \
                        || echo -e "  ${RED}✗${NC} 自动合并失败，请手动合并 ${CYAN}$snippet${NC}"
                fi
            fi
        else
            echo -e "  请手动将以下文件内容合并到 ${CYAN}$claude_settings${NC}:"
            echo -e "  ${CYAN}$plugin_dir/hooks/settings-snippet.json${NC}"
            [ ! -f "$claude_settings" ] && echo -e "  ${YELLOW}提示: settings.json 不存在，请先创建${NC}"
            ! command -v jq >/dev/null 2>&1 && echo -e "  ${YELLOW}提示: 安装 jq 可启用自动合并 (brew install jq)${NC}"
        fi
    fi
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

        # 卸载 agents/ 文件（按 plugin 源目录中的文件名逐个删除）
        local plugin_agents_dir="$SCRIPT_DIR/plugins/$plugin_name/agents"
        if [ -d "$plugin_agents_dir" ]; then
            for agent_file in "$plugin_agents_dir"/*; do
                local agent_basename
                agent_basename=$(basename "$agent_file")
                local agent_dst="$target/agents/$agent_basename"
                if [ -f "$agent_dst" ]; then
                    rm "$agent_dst"
                    echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 agent: ${CYAN}$agent_dst${NC}"
                    removed=true
                fi
            done
        fi
    done

    # Hook 配置清理提示
    if [ -f "$SCRIPT_DIR/plugins/$plugin_name/hooks/settings-snippet.json" ]; then
        echo -e "${YELLOW}⚠ 请手动检查并移除 ~/.claude/settings.json 中该 Hook 的配置${NC}"
    fi

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
