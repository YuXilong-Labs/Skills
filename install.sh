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

    local has_jq=0
    if command -v jq >/dev/null 2>&1; then
        has_jq=1
    fi

    for target in "${TARGETS[@]}"; do
        local target_name
        target_name=$(basename "$target")
        local skills_dst="$target/skills"
        local commands_dst="$target/commands"

        mkdir -p "$skills_dst"
        mkdir -p "$commands_dst"

        # ===== Manifest：清理上次安装中已被仓库删除的产物 =====
        # 仅在 jq 可用时启用，缺 jq 时退化为现有覆盖式逻辑（不清理残留）。
        local manifest_dir="$target/.skills-manifest"
        local manifest_file="$manifest_dir/${plugin_name}.json"
        local old_skills_list=""
        local old_commands_list=""
        local old_agents_list=""
        local old_has_scripts=0
        if [ "$has_jq" -eq 1 ] && [ -f "$manifest_file" ]; then
            # 单次 jq 调用一次性读取所有字段，避免 4 次 fork
            local old_dump
            old_dump=$(jq -r '
                (.skills // []) | @tsv,
                (.commands // []) | @tsv,
                (.agents // []) | @tsv,
                (.has_scripts // false | tostring)
            ' "$manifest_file" 2>/dev/null || true)
            old_skills_list=$(printf '%s\n' "$old_dump" | sed -n '1p' | tr '\t' '\n')
            old_commands_list=$(printf '%s\n' "$old_dump" | sed -n '2p' | tr '\t' '\n')
            old_agents_list=$(printf '%s\n' "$old_dump" | sed -n '3p' | tr '\t' '\n')
            local old_scripts_flag
            old_scripts_flag=$(printf '%s\n' "$old_dump" | sed -n '4p')
            [ "$old_scripts_flag" = "true" ] && old_has_scripts=1 || old_has_scripts=0
        fi

        # 计算当前仓库内的清单
        local new_skills_list=""
        if [ -d "$plugin_dir/skills" ]; then
            new_skills_list=$(find "$plugin_dir/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
        fi
        local new_commands_list=""
        if [ -d "$plugin_dir/commands" ]; then
            new_commands_list=$(find "$plugin_dir/commands" -mindepth 1 -maxdepth 1 -type f -exec basename {} \; 2>/dev/null | sort)
        fi
        local new_agents_list=""
        if [ -d "$plugin_dir/agents" ]; then
            new_agents_list=$(find "$plugin_dir/agents" -mindepth 1 -maxdepth 1 -type f -exec basename {} \; 2>/dev/null | sort)
        fi
        local new_has_scripts=0
        [ -d "$plugin_dir/scripts" ] && new_has_scripts=1

        # 差集 = 旧 - 新 → 逐条删除（comm -23 要求 sort 输入）
        if [ "$has_jq" -eq 1 ] && [ -n "$old_skills_list" ]; then
            local stale_skills
            stale_skills=$(comm -23 <(echo "$old_skills_list" | sort) <(echo "$new_skills_list") || true)
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                local p="$skills_dst/$name"
                if [ -d "$p" ]; then
                    rm -rf "$p"
                    echo -e "${YELLOW}-${NC} [${target_name}] 清理失效 skill: ${CYAN}$p${NC}"
                fi
            done <<< "$stale_skills"
        fi
        if [ "$has_jq" -eq 1 ] && [ -n "$old_commands_list" ]; then
            local stale_commands
            stale_commands=$(comm -23 <(echo "$old_commands_list" | sort) <(echo "$new_commands_list") || true)
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                local p="$commands_dst/$name"
                if [ -f "$p" ]; then
                    rm -f "$p"
                    echo -e "${YELLOW}-${NC} [${target_name}] 清理失效 command: ${CYAN}$p${NC}"
                fi
            done <<< "$stale_commands"
        fi
        if [ "$has_jq" -eq 1 ] && [ -n "$old_agents_list" ]; then
            local stale_agents
            stale_agents=$(comm -23 <(echo "$old_agents_list" | sort) <(echo "$new_agents_list") || true)
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                local p="$target/agents/$name"
                if [ -f "$p" ]; then
                    rm -f "$p"
                    echo -e "${YELLOW}-${NC} [${target_name}] 清理失效 agent: ${CYAN}$p${NC}"
                fi
            done <<< "$stale_agents"
        fi
        if [ "$has_jq" -eq 1 ] && [ "$old_has_scripts" -eq 1 ] && [ "$new_has_scripts" -eq 0 ]; then
            local p="$target/scripts/$plugin_name"
            if [ -d "$p" ]; then
                rm -rf "$p"
                echo -e "${YELLOW}-${NC} [${target_name}] 清理失效 scripts: ${CYAN}$p${NC}"
            fi
        fi

        # 复制 skills/ 子目录（先清空对应目标子目录，确保仓库内删除的引用文件不残留）
        if [ -d "$plugin_dir/skills" ]; then
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                rm -rf "${skills_dst:?}/$name"
            done <<< "$new_skills_list"
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
            # 先清空整个 plugin 专属脚本目录，避免旧脚本残留
            rm -rf "$scripts_dst"
            mkdir -p "$scripts_dst"
            cp -r "$plugin_dir/scripts/"* "$scripts_dst/"
            chmod +x "$scripts_dst"/*.sh 2>/dev/null || true
            echo -e "${GREEN}✓${NC} [${target_name}] 已安装 scripts: ${CYAN}$scripts_dst/${NC}"
        fi

        # 写入新 manifest（单次 jq 调用：通过 3 行 TSV stdin 一次性构建）
        if [ "$has_jq" -eq 1 ]; then
            mkdir -p "$manifest_dir"
            local has_scripts_json="false"
            [ "$new_has_scripts" -eq 1 ] && has_scripts_json="true"
            {
                printf '%s\n' "$new_skills_list" | paste -sd '\t' -
                printf '%s\n' "$new_commands_list" | paste -sd '\t' -
                printf '%s\n' "$new_agents_list" | paste -sd '\t' -
            } | jq -Rsc --argjson has_scripts "$has_scripts_json" '
                split("\n")
                | def clean: split("\t") | map(select(. != ""));
                {
                    skills:    (.[0] // "" | clean),
                    commands:  (.[1] // "" | clean),
                    agents:    (.[2] // "" | clean),
                    has_scripts: $has_scripts
                }
            ' > "$manifest_file.tmp" && mv "$manifest_file.tmp" "$manifest_file"
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

    # 把 scripts/.bin-links 声明的命令软链到 PATH 上的可写目录（便于终端直接调用，如 `xcb`）
    # 软链统一指向 .claude 目标下的脚本（install.sh 始终双目标安装，该副本必然存在）。
    if [ -f "$plugin_dir/scripts/.bin-links" ]; then
        local bindir
        bindir=$(pick_bin_dir)
        if [ -n "$bindir" ]; then
            while IFS='=' read -r link script; do
                link=$(printf '%s' "$link" | tr -d '[:space:]')
                script=$(printf '%s' "$script" | tr -d '[:space:]')
                [ -z "$link" ] && continue
                case "$link" in \#*) continue ;; esac
                local target_script="$HOME/.claude/scripts/$plugin_name/$script"
                ln -sf "$target_script" "$bindir/$link"
                echo -e "${GREEN}✓${NC} 已链接命令: ${CYAN}$bindir/$link${NC} → ${plugin_name}/${script}"
            done < "$plugin_dir/scripts/.bin-links"
        else
            echo -e "${YELLOW}⚠ PATH 上无可写 bin 目录，跳过命令软链${NC}"
            echo -e "  可手动加入 PATH：${CYAN}export PATH=\"\$HOME/.claude/scripts/$plugin_name:\$PATH\"${NC}"
        fi
    fi

    # Claude Hook 配置 upsert 到 settings.json
    if [ -f "$plugin_dir/hooks/settings-snippet.json" ]; then
        local claude_settings="$HOME/.claude/settings.json"
        echo
        echo -e "${YELLOW}⚡ Hook 配置需合并到 Claude Code settings:${NC}"
        if command -v jq >/dev/null 2>&1; then
            [ -f "$claude_settings" ] || echo '{}' > "$claude_settings"
            merge_hooks_into "$plugin_dir/hooks/settings-snippet.json" "$claude_settings"
        else
            echo -e "  请手动将以下文件内容合并到 ${CYAN}$claude_settings${NC}:"
            echo -e "  ${CYAN}$plugin_dir/hooks/settings-snippet.json${NC}"
            echo -e "  ${YELLOW}提示: 安装 jq 可启用自动合并 (brew install jq)${NC}"
        fi
    fi

    # Codex Hook 配置 upsert 到 hooks.json
    if [ -f "$plugin_dir/hooks/codex-settings-snippet.json" ]; then
        local codex_hooks="$HOME/.codex/hooks.json"
        echo
        echo -e "${YELLOW}⚡ Hook 配置需合并到 Codex hooks.json:${NC}"
        if command -v jq >/dev/null 2>&1; then
            [ -f "$codex_hooks" ] || echo '{"hooks":{}}' > "$codex_hooks"
            merge_hooks_into "$plugin_dir/hooks/codex-settings-snippet.json" "$codex_hooks"
        else
            echo -e "  ${YELLOW}提示: 安装 jq 可启用自动合并 (brew install jq)${NC}"
        fi
    fi
}

# Upsert PostToolUse hook entries from <snippet> into <settings>。
# 以每条 entry 的 .hooks[0].statusMessage 作为标识 key：
#   - 不存在 → append（added）
#   - 存在且内容相同 → 跳过（unchanged）
#   - 存在但内容不同 → 替换（updated）
# 写入采用 tmp + mv 原子替换，jq 失败保留原文件。
# 选择 PATH 上第一个存在且可写的 bin 目录（偏好用户级 ~/.local/bin），找不到则输出空。
pick_bin_dir() {
    local d
    for d in "$HOME/.local/bin" "/usr/local/bin" "/opt/homebrew/bin" "$HOME/bin"; do
        case ":$PATH:" in *":$d:"*) ;; *) continue ;; esac
        [ -d "$d" ] && [ -w "$d" ] && { printf '%s' "$d"; return 0; }
    done
    return 0
}

# 移除某 plugin 经 .bin-links 创建的命令软链（仅删指向该 plugin scripts 的软链，安全）。
unlink_plugin_bins() {
    local plugin_name="$1"
    local binlinks="$SCRIPT_DIR/plugins/$plugin_name/scripts/.bin-links"
    [ -f "$binlinks" ] || return 0
    local link script d tgt
    while IFS='=' read -r link script; do
        link=$(printf '%s' "$link" | tr -d '[:space:]')
        [ -z "$link" ] && continue
        case "$link" in \#*) continue ;; esac
        for d in "$HOME/.local/bin" "/usr/local/bin" "/opt/homebrew/bin" "$HOME/bin"; do
            if [ -L "$d/$link" ]; then
                tgt=$(readlink "$d/$link")
                case "$tgt" in
                    */scripts/"$plugin_name"/*)
                        rm -f "$d/$link"
                        echo -e "${GREEN}✓${NC} 已移除命令软链: ${CYAN}$d/$link${NC}"
                        ;;
                esac
            fi
        done
    done < "$binlinks"
}

# 从 settings/hooks 文件中移除某 snippet 声明的 hook 条目（按 statusMessage 匹配，
# 遍历 snippet 中所有事件类型）。卸载时调用，避免残留指向已删脚本的悬空 hook。
remove_hooks_from() {
    local snippet="$1"
    local settings="$2"
    [ -f "$settings" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local result
    result=$(jq --slurpfile snip "$snippet" '
        ($snip[0].hooks // {}) as $byevt
        | reduce ($byevt | keys_unsorted[]) as $evt (.;
            ([ $byevt[$evt][].hooks[0].statusMessage // empty ]) as $msgs
            | .hooks[$evt] = ( (.hooks[$evt] // [])
                | map(select( (.hooks[0].statusMessage // "—none—") as $sm | ($msgs | index($sm)) | not )) )
            | if ((.hooks[$evt] // []) | length) == 0 then del(.hooks[$evt]) else . end
          )
        | if (.hooks // {}) == {} then del(.hooks) else . end
    ' "$settings" 2>/dev/null)

    if [ -n "$result" ]; then
        printf '%s\n' "$result" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
        echo -e "  ${GREEN}✓${NC} 已从 ${CYAN}$settings${NC} 移除该 plugin 的 Hook 条目"
    fi
}

merge_hooks_into() {
    local snippet="$1"
    local settings="$2"

    # 单次 jq 调用：遍历 snippet 中存在的所有事件类型（PreToolUse / PostToolUse / ...），
    # 对每条 entry 按 statusMessage 定位并 upsert。
    # 输出格式：第 1 行 JSON = 新 settings；第 2 行 = "added\tupdated\tunchanged" 统计。
    local result
    result=$(jq -nc --slurpfile snip "$snippet" --slurpfile cur "$settings" '
        ($snip[0].hooks // {}) as $byevt
        | def upsert($s; $evt; $e):
            ($e.hooks[0].statusMessage // "") as $msg
            | ($s.hooks[$evt] // []) as $arr
            | if $msg == "" then
                  {settings: ($s | .hooks[$evt] = ($arr + [$e])), action: "added"}
              else
                  ([range(0; $arr|length)] | map(. as $i | select(any($arr[$i].hooks[]?; .statusMessage == $msg))) | first // -1) as $idx
                  | if $idx == -1 then
                        {settings: ($s | .hooks[$evt] = ($arr + [$e])), action: "added"}
                    elif ($arr[$idx] == $e) then
                        {settings: $s, action: "unchanged"}
                    else
                        {settings: ($s | .hooks[$evt][$idx] = $e), action: "updated"}
                    end
              end
        ;
        reduce ($byevt | keys_unsorted[]) as $evt (
            {settings: $cur[0], added: 0, updated: 0, unchanged: 0};
            reduce ($byevt[$evt][]) as $e (.;
                upsert(.settings; $evt; $e) as $r
                | .settings = $r.settings
                | if   $r.action == "added"     then .added     += 1
                  elif $r.action == "updated"   then .updated   += 1
                  else                                .unchanged += 1
                  end
            )
        )
        | .settings, "\(.added) \(.updated) \(.unchanged)"
    ' 2>/dev/null)

    if [ -z "$result" ]; then
        return 0
    fi

    local new_settings stats
    new_settings=$(printf '%s' "$result" | sed -n '1p')
    stats=$(printf '%s' "$result" | sed -n '2p' | tr -d '"')
    local added updated unchanged
    read -r added updated unchanged <<< "$stats"

    if [ "${added:-0}" -gt 0 ] || [ "${updated:-0}" -gt 0 ]; then
        printf '%s\n' "$new_settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
    fi

    if [ "${added:-0}" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} 已新增 $added 条 Hook 配置到 ${CYAN}$settings${NC}"
    fi
    if [ "${updated:-0}" -gt 0 ]; then
        echo -e "  ${GREEN}↻${NC} 已更新 $updated 条 Hook 配置（command 内容变化）"
    fi
    if [ "${unchanged:-0}" -gt 0 ]; then
        echo -e "  ${GREEN}=${NC} $unchanged 条 Hook 已是最新，无需更改"
    fi
}

uninstall_skill() {
    local plugin_name="$1"
    local removed=false
    local has_jq=0
    command -v jq >/dev/null 2>&1 && has_jq=1

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

        # 通过 manifest 清理本插件曾安装过的所有产物（skills/commands/agents/scripts）
        local manifest_file="$target/.skills-manifest/${plugin_name}.json"
        if [ "$has_jq" -eq 1 ] && [ -f "$manifest_file" ]; then
            local m_skills m_commands m_agents m_has_scripts
            m_skills=$(jq -r '(.skills // []) | .[]' "$manifest_file" 2>/dev/null || true)
            m_commands=$(jq -r '(.commands // []) | .[]' "$manifest_file" 2>/dev/null || true)
            m_agents=$(jq -r '(.agents // []) | .[]' "$manifest_file" 2>/dev/null || true)
            m_has_scripts=$(jq -r '.has_scripts // false' "$manifest_file" 2>/dev/null || echo "false")
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                local p="$target/skills/$name"
                if [ -d "$p" ]; then
                    rm -rf "$p"
                    echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 skill: ${CYAN}$p${NC}"
                    removed=true
                fi
            done <<< "$m_skills"
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                local p="$target/commands/$name"
                if [ -f "$p" ]; then
                    rm -f "$p"
                    echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 command: ${CYAN}$p${NC}"
                    removed=true
                fi
            done <<< "$m_commands"
            while IFS= read -r name; do
                [ -z "$name" ] && continue
                local p="$target/agents/$name"
                if [ -f "$p" ]; then
                    rm -f "$p"
                    echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 agent: ${CYAN}$p${NC}"
                    removed=true
                fi
            done <<< "$m_agents"
            if [ "$m_has_scripts" = "true" ]; then
                local p="$target/scripts/$plugin_name"
                if [ -d "$p" ]; then
                    rm -rf "$p"
                    echo -e "${GREEN}✓${NC} [${target_name}] 已卸载 scripts: ${CYAN}$p${NC}"
                    removed=true
                fi
            fi
            rm -f "$manifest_file"
        fi

        # 卸载 agents/ 文件（按 plugin 源目录中的文件名逐个删除，作为 manifest 缺失时的兜底）
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

    # 移除 .bin-links 创建的命令软链
    unlink_plugin_bins "$plugin_name"

    # Hook 配置清理：从两端 settings/hooks 文件中移除该 plugin 的 hook 条目
    local plugin_hooks_dir="$SCRIPT_DIR/plugins/$plugin_name/hooks"
    if [ -f "$plugin_hooks_dir/settings-snippet.json" ]; then
        remove_hooks_from "$plugin_hooks_dir/settings-snippet.json" "$HOME/.claude/settings.json"
        removed=true
    fi
    if [ -f "$plugin_hooks_dir/codex-settings-snippet.json" ]; then
        remove_hooks_from "$plugin_hooks_dir/codex-settings-snippet.json" "$HOME/.codex/hooks.json"
        removed=true
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
