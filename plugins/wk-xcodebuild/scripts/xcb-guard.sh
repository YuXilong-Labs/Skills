#!/bin/bash
# xcb-guard.sh — PreToolUse 守卫：拦截裸 xcodebuild 调用，引导改用 xcb-run.sh
# Created by yuxilong on 2026/06/03
#
# 适用于 Claude Code 与 Codex CLI（两者 PreToolUse hook 同构）。
# 从 stdin 读取 hook JSON：{ tool_name, tool_input: { command } }。
#
# 判定：tool_name 为 Bash 且 command 含词边界 xcodebuild，
#       且未走包装器（xcb-run.sh / wk-xcodebuild）、未设逃生舱 WK_XCB_BYPASS
#       → 输出 deny 决策，提示改用包装器。
# 否则静默放行（无输出，退出 0）。
#
# deny 输出格式两端通用（hookSpecificOutput.permissionDecision=deny）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/xcb-run.sh"

payload="$(cat 2>/dev/null)"

# 提取 tool_name 与 command（优先 jq，缺失则降级正则）
tool_name=""
command_str=""
if command -v jq >/dev/null 2>&1; then
    tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)"
    command_str="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
    # 降级：直接在整段 payload 上判断（精度略降但可用）
    command_str="$payload"
fi

# 非 Bash 工具直接放行（jq 路径才有 tool_name；降级路径不拦工具类型）
if [ -n "$tool_name" ] && [ "$tool_name" != "Bash" ]; then
    exit 0
fi

# 逃生舱 / 已走包装器 → 放行
case "$command_str" in
    *WK_XCB_BYPASS*|*xcb-run.sh*|*wk-xcodebuild*) exit 0 ;;
esac

# 词边界匹配裸 xcodebuild（含 /usr/bin/xcodebuild 这类绝对路径调用）。
# 前置边界允许 / . - 等路径分隔符，仅排除 alnum/_（避免 myxcodebuild 之类误判）。
if printf '%s' "$command_str" | grep -Eq '(^|[^[:alnum:]_])xcodebuild([^[:alnum:]_]|$)'; then
    reason="检测到裸 xcodebuild 调用。请改用 wk-xcodebuild 包装器以自动选择 USB 真机目标并精简输出（节省 token）：
  $WRAPPER <相同的 xcodebuild 参数>
例：$WRAPPER build -scheme App -workspace App.xcworkspace
如确需直接运行原始 xcodebuild，可加前缀 WK_XCB_BYPASS=1。"
    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg r "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $r
            }
        }'
    else
        # 无 jq 时用 exit 2 + stderr 表达 deny（两端均支持）
        printf '%s\n' "$reason" >&2
        exit 2
    fi
    exit 0
fi

exit 0
