#!/bin/bash
# codex_apply_patch_check.sh — Codex PostToolUse 禁止词检查
# Created by yuxilong on 2026/06/04
#
# Codex 改文件走 apply_patch（而非 Claude 的 Edit/Write），tool_input.command 是补丁文本。
# 本脚本从补丁里解析受影响的 iOS 源码文件，跑 ios-blocked-words-check 的检查脚本，
# 命中违规则以 Codex hookSpecificOutput.additionalContext 注入提示（非阻塞）。
#
# stdin：hook JSON（tool_name / cwd / tool_input.command 或 tool_input.file_path）。
# 依赖：jq、python3。检查脚本缺失或无依赖则静默跳过（exit 0）。

set -uo pipefail

CHECK="$HOME/.codex/skills/ios-blocked-words-check/scripts/check_blocked_words.py"
[ -f "$CHECK" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null)"
[ -n "$payload" ] || exit 0

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"

# 受影响文件：优先 file_path（Edit/Write 风格）；否则解析 apply_patch 补丁文本
files="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
if [ -z "$files" ]; then
    patch="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.patch // .tool_input.input // empty' 2>/dev/null)"
    # 解析 "*** Add File: <path>" / "*** Update File: <path>" / "*** Move to: <path>"
    files="$(printf '%s\n' "$patch" | awk '
        /^\*\*\* (Add|Update) File: / { sub(/^\*\*\* (Add|Update) File: /, ""); print }
        /^\*\*\* Move to: /            { sub(/^\*\*\* Move to: /, ""); print }
    ')"
fi
[ -n "$files" ] || exit 0

violations=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
        *.h|*.m|*.mm|*.swift|*.c|*.cpp) ;;
        *) continue ;;
    esac
    # 补丁里是相对路径，补成基于 cwd 的绝对路径；文件须已落盘（PostToolUse）
    case "$f" in
        /*) path="$f" ;;
        *)  path="${cwd:+$cwd/}$f" ;;
    esac
    [ -f "$path" ] || continue
    out="$(python3 "$CHECK" "$path" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        violations="${violations}
${out}"
    fi
done <<< "$files"

if [ -n "$violations" ]; then
    jq -nc --arg c "iOS 禁止关键词检查失败，禁止 git commit。违规详情：${violations}" '{
        hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $c }
    }'
fi
exit 0
