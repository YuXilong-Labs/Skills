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
                skill_md=""
                if [ -d "$plugin_dir/skills" ]; then
                    skill_md=$(find "$plugin_dir/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null | head -1 || true)
                fi
                if [ -n "$skill_md" ] && [ -f "$skill_md" ]; then
                    desc=$(awk '
                        /^description:/ {
                            sub(/^description:[[:space:]]*/, "", $0)
                            if ($0 != "|" && $0 != "") {
                                print
                                exit
                            }
                            multiline = 1
                            next
                        }
                        multiline && /^  / {
                            sub(/^  /, "", $0)
                            print
                            exit
                        }
                        multiline {
                            exit
                        }
                    ' "$skill_md" 2>/dev/null || true)
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
                elif [ -d "$plugin_dir/rules" ]; then
                    # Rules 类 plugin（无 SKILL.md，有 rules/ 目录）
                    rules_desc=""
                    if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
                        rules_desc=$(sed -n 's/.*"description":\s*"\(.*\)".*/\1/p' "$plugin_dir/.claude-plugin/plugin.json" 2>/dev/null | head -1)
                    fi
                    echo -e "  ${BLUE}📋${NC} ${plugin_name} ${CYAN}(Rules)${NC}"
                    [ -n "$rules_desc" ] && echo -e "    ${YELLOW}${rules_desc}${NC}"
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

        # 复制 scripts/ 目录（plugin 辅助脚本，双目标）
        if [ -d "$plugin_dir/scripts" ]; then
            local scripts_dst="$target/scripts/$plugin_name"
            mkdir -p "$scripts_dst"
            cp -r "$plugin_dir/scripts/"* "$scripts_dst/"
            chmod +x "$scripts_dst"/*.sh 2>/dev/null || true
            echo -e "${GREEN}✓${NC} [${target_name}] 已安装 scripts: ${CYAN}$scripts_dst/${NC}"
        fi

        # 复制 rules/ 子目录（编码规范规则）
        if [ -d "$plugin_dir/rules" ]; then
            local rules_dst="$target/rules"
            mkdir -p "$rules_dst"
            if [ "$target_name" = ".claude" ]; then
                # Claude Code：按语言目录复制（支持 paths frontmatter）
                # 先清理各语言子目录，防止旧规则文件残留
                for lang_dir in "$plugin_dir/rules"/*/; do
                    [ -d "$lang_dir" ] || continue
                    local lang_name
                    lang_name=$(basename "$lang_dir")
                    rm -rf "${rules_dst:?}/$lang_name"
                    mkdir -p "$rules_dst/$lang_name"
                done
                cp -r "$plugin_dir/rules/"* "$rules_dst/"
                echo -e "${GREEN}✓${NC} [${target_name}] 已安装 rules: ${CYAN}$rules_dst/${NC}"

                # 写入版本号（用于 check-and-upgrade.sh 比对）
                if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
                    local plugin_version
                    plugin_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_dir/.claude-plugin/plugin.json" | head -1)
                    if [ -n "$plugin_version" ]; then
                        echo "$plugin_version" > "$rules_dst/${plugin_name}.version"
                    fi
                fi
            elif [ "$target_name" = ".codex" ]; then
                # Codex CLI：合并为单文件（Codex 不支持分目录 rules）
                local merged="$rules_dst/${plugin_name}.md"
                echo "# iOS Development Rules (auto-generated)" > "$merged"
                echo "" >> "$merged"
                for lang_dir in "$plugin_dir/rules"/*/; do
                    if [ -d "$lang_dir" ]; then
                        local lang_name
                        lang_name=$(basename "$lang_dir")
                        echo "---" >> "$merged"
                        echo "## $lang_name" >> "$merged"
                        echo "" >> "$merged"
                        for rule_file in "$lang_dir"*.md; do
                            [ -f "$rule_file" ] || continue
                            # 跳过 frontmatter，只保留正文
                            awk 'BEGIN{skip=0} /^---$/{skip++; next} skip>=2{print}' "$rule_file" >> "$merged"
                            echo "" >> "$merged"
                        done
                        # 复制非 .md 文件（如 .clang-format）到 Codex 对应语言目录
                        for extra_file in "$lang_dir".*; do
                            [ -f "$extra_file" ] || continue
                            local codex_lang_dst="$rules_dst/$lang_name"
                            mkdir -p "$codex_lang_dst"
                            cp "$extra_file" "$codex_lang_dst/"
                        done
                    fi
                done
                echo -e "${GREEN}✓${NC} [${target_name}] 已安装 rules: ${CYAN}$merged${NC}"

                # 写入版本号（与 Claude 对称，用于 check-and-upgrade.sh 比对）
                if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
                    local plugin_version
                    plugin_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_dir/.claude-plugin/plugin.json" | head -1)
                    if [ -n "$plugin_version" ]; then
                        echo "$plugin_version" > "$rules_dst/${plugin_name}.version"
                    fi
                fi
            fi
        fi
    done

    # Hook 配置提示（需手动或自动合并到 settings.json）
    if [ -f "$plugin_dir/hooks/settings-snippet.json" ]; then
        local claude_settings="$HOME/.claude/settings.json"
        echo
        echo -e "${YELLOW}⚡ Hook 配置需合并到 Claude Code settings:${NC}"
        if command -v jq >/dev/null 2>&1 && [ -f "$claude_settings" ]; then
            # 自动合并 hook 配置：逐条 hook 去重（按 statusMessage 或 command 前64字符）
            local snippet="$plugin_dir/hooks/settings-snippet.json"
            local hooks_to_add
            hooks_to_add=$(jq '.hooks.PostToolUse // []' "$snippet" 2>/dev/null)
            if [ -n "$hooks_to_add" ] && [ "$hooks_to_add" != "[]" ]; then
                local added=0
                local skipped=0
                # 遍历 snippet 中每个 PostToolUse 条目，逐条去重后 append
                local count
                count=$(jq 'length' <<< "$hooks_to_add" 2>/dev/null || echo 0)
                for i in $(seq 0 $((count - 1))); do
                    local entry
                    entry=$(jq ".[$i]" <<< "$hooks_to_add" 2>/dev/null)
                    # 取该条目第一个 hook 的 statusMessage 作为去重 key
                    local msg
                    msg=$(jq -r '.hooks[0].statusMessage // empty' <<< "$entry" 2>/dev/null)
                    local exists=0
                    if [ -n "$msg" ]; then
                        exists=$(jq --arg m "$msg" '[.hooks.PostToolUse[]?.hooks[]? | select(.statusMessage == $m)] | length' "$claude_settings" 2>/dev/null || echo 0)
                    fi
                    if [ "${exists:-0}" -gt 0 ]; then
                        skipped=$((skipped + 1))
                    else
                        jq --argjson e "$entry" '.hooks.PostToolUse = (.hooks.PostToolUse // []) + [$e]' "$claude_settings" > "${claude_settings}.tmp" \
                            && mv "${claude_settings}.tmp" "$claude_settings"
                        added=$((added + 1))
                    fi
                done
                if [ $added -gt 0 ]; then
                    echo -e "  ${GREEN}✓${NC} 已自动合并 $added 条 Hook 配置到 ${CYAN}$claude_settings${NC}"
                fi
                if [ $skipped -gt 0 ]; then
                    echo -e "  ${GREEN}✓${NC} $skipped 条 Hook 已存在于 settings.json，无需重复添加"
                fi
            fi
        else
            echo -e "  请手动将以下文件内容合并到 ${CYAN}$claude_settings${NC}:"
            echo -e "  ${CYAN}$plugin_dir/hooks/settings-snippet.json${NC}"
            [ ! -f "$claude_settings" ] && echo -e "  ${YELLOW}提示: settings.json 不存在，请先创建${NC}"
            ! command -v jq >/dev/null 2>&1 && echo -e "  ${YELLOW}提示: 安装 jq 可启用自动合并 (brew install jq)${NC}"
        fi
    fi

    # Codex Hook 配置自动合并到 hooks.json
    if [ -f "$plugin_dir/hooks/codex-settings-snippet.json" ]; then
        local codex_hooks="$HOME/.codex/hooks.json"
        echo
        echo -e "${YELLOW}⚡ Hook 配置需合并到 Codex hooks.json:${NC}"
        if command -v jq >/dev/null 2>&1; then
            local codex_snippet="$plugin_dir/hooks/codex-settings-snippet.json"
            local codex_hooks_to_add
            codex_hooks_to_add=$(jq '.hooks.PostToolUse // []' "$codex_snippet" 2>/dev/null)
            if [ -n "$codex_hooks_to_add" ] && [ "$codex_hooks_to_add" != "[]" ]; then
                if [ ! -f "$codex_hooks" ]; then
                    echo '{"hooks":{}}' > "$codex_hooks"
                fi
                local codex_added=0
                local codex_skipped=0
                local codex_count
                codex_count=$(jq 'length' <<< "$codex_hooks_to_add" 2>/dev/null || echo 0)
                for i in $(seq 0 $((codex_count - 1))); do
                    local codex_entry
                    codex_entry=$(jq ".[$i]" <<< "$codex_hooks_to_add" 2>/dev/null)
                    local codex_msg
                    codex_msg=$(jq -r '.hooks[0].statusMessage // empty' <<< "$codex_entry" 2>/dev/null)
                    local codex_exists=0
                    if [ -n "$codex_msg" ]; then
                        codex_exists=$(jq --arg m "$codex_msg" '[.hooks.PostToolUse[]?.hooks[]? | select(.statusMessage == $m)] | length' "$codex_hooks" 2>/dev/null || echo 0)
                    fi
                    if [ "${codex_exists:-0}" -gt 0 ]; then
                        codex_skipped=$((codex_skipped + 1))
                    else
                        jq --argjson e "$codex_entry" '.hooks.PostToolUse = (.hooks.PostToolUse // []) + [$e]' "$codex_hooks" > "${codex_hooks}.tmp" \
                            && mv "${codex_hooks}.tmp" "$codex_hooks"
                        codex_added=$((codex_added + 1))
                    fi
                done
                if [ $codex_added -gt 0 ]; then
                    echo -e "  ${GREEN}✓${NC} 已自动合并 $codex_added 条 Hook 配置到 ${CYAN}$codex_hooks${NC}"
                fi
                if [ $codex_skipped -gt 0 ]; then
                    echo -e "  ${GREEN}✓${NC} $codex_skipped 条 Hook 已存在于 hooks.json，无需重复添加"
                fi
            fi
        else
            echo -e "  ${YELLOW}提示: 安装 jq 可启用自动合并 (brew install jq)${NC}"
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

        # 卸载 rules/ 目录（按 plugin 源目录中的语言子目录逐个删除）
        local plugin_rules_dir="$SCRIPT_DIR/plugins/$plugin_name/rules"
        if [ -d "$plugin_rules_dir" ]; then
            if [ "$target_name" = ".claude" ]; then
                for lang_dir in "$plugin_rules_dir"/*/; do
                    [ -d "$lang_dir" ] || continue
                    local lang_name
                    lang_name=$(basename "$lang_dir")
                    local rules_dst="$target/rules/$lang_name"
                    if [ -d "$rules_dst" ]; then
                        rm -rf "$rules_dst"
                        echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 rules: ${CYAN}$rules_dst${NC}"
                        removed=true
                    fi
                done
            elif [ "$target_name" = ".codex" ]; then
                local merged_dst="$target/rules/${plugin_name}.md"
                if [ -f "$merged_dst" ]; then
                    rm "$merged_dst"
                    echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 rules: ${CYAN}$merged_dst${NC}"
                    removed=true
                fi
            fi
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
