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

# 解析自身真实目录（兼容经符号链接调用）
_src="${BASH_SOURCE[0]}"
while [ -h "$_src" ]; do
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$_src")" && pwd)"
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

# 计算改写后的命令：裸 xcodebuild 或 swift build/test → 改写为走包装器。
# 前置边界允许 / . - 等路径分隔符（含 /usr/bin/xcodebuild、./swift 这类）。
# sed 仅含 sentinel（不把 WRAPPER 注入正则，避免路径特殊字符/空格破坏 sed），
# 再用 bash 字面量替换 sentinel → "$WRAPPER"（路径可能含空格，故带引号）。
sentinel="@@WK_XCB_WRAPPER@@"
rewritten=""; kind=""

if printf '%s' "$command_str" | grep -Eq '(^|[^[:alnum:]_])xcodebuild([^[:alnum:]_]|$)'; then
    kind="xcodebuild"
    # 把 (路径/)?xcodebuild 整个可执行 token 换成包装器（包装器默认即跑 xcodebuild）
    rewritten="$(printf '%s' "$command_str" | sed -E "s#(^|[[:space:];&|(])([^[:space:];&|()]*/)?xcodebuild([[:space:]]|\$)#\1${sentinel}\3#")"
elif printf '%s' "$command_str" | grep -Eq '(^|[^[:alnum:]_])swift[[:space:]]+(build|test)([[:space:]]|$)'; then
    kind="swift"
    # 在 (路径/)?swift 前插入包装器并保留 swift：swift build … → <wrapper> swift build …
    rewritten="$(printf '%s' "$command_str" | sed -E "s#(^|[[:space:];&|(])([^[:space:];&|()]*/)?swift([[:space:]]+(build|test)([[:space:]]|\$))#\1${sentinel} swift\3#")"
elif printf '%s' "$command_str" | grep -Eq '(^|[^[:alnum:]_])xcresulttool[[:space:]]+get[[:space:]]+test-results[[:space:]]+(summary|tests)([[:space:]]|$)'; then
    kind="xcresulttool"
    # xcrun xcresulttool get test-results summary … → <wrapper> result …
    # （tests → result --tests；--path 等后续参数原样保留，包装器忽略未知 flag）
    rewritten="$(printf '%s' "$command_str" | sed -E "s#(^|[[:space:];&|(])(xcrun[[:space:]]+)?([^[:space:];&|()]*/)?xcresulttool[[:space:]]+get[[:space:]]+test-results[[:space:]]+summary#\1${sentinel} result#")"
    if [ "$rewritten" = "$command_str" ]; then
        rewritten="$(printf '%s' "$command_str" | sed -E "s#(^|[[:space:];&|(])(xcrun[[:space:]]+)?([^[:space:];&|()]*/)?xcresulttool[[:space:]]+get[[:space:]]+test-results[[:space:]]+tests#\1${sentinel} result --tests#")"
    fi
    # xcresulttool 改写失败 → 放行（与 xcodebuild 不同：原始输出大但跑得快，宁可放行不误伤）
    [ "$rewritten" = "$command_str" ] && exit 0
else
    exit 0   # 既非 xcodebuild / swift build/test / xcresulttool test-results → 放行
fi

new_cmd="${rewritten/${sentinel}/\"$WRAPPER\"}"

# 改写成功（sentinel 被替换）且有 jq → allow + updatedInput（Claude / Codex 通用）
if command -v jq >/dev/null 2>&1 && [ "$new_cmd" != "$rewritten" ]; then
    jq -nc --arg c "$new_cmd" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            permissionDecisionReason: "已自动改用 wk-xcodebuild 包装器（xcodebuild 选真机 / swift 本机构建 + 精简输出，省 token）",
            updatedInput: { command: $c }
        }
    }'
    exit 0
fi

# xcresulttool：改写失败 / 无 jq → 放行原命令（不 deny，避免误伤只读查询）
[ "$kind" = "xcresulttool" ] && exit 0

# 改写失败 / 无 jq → 回退 deny（绝不让裸命令静默跑掉）
reason="检测到裸 ${kind} 调用，且自动改写失败。请改用包装器：
  \"$WRAPPER\" <参数>            （swift 用：\"$WRAPPER\" swift <参数>）
如确需直接运行，可加前缀 WK_XCB_BYPASS=1。"
if command -v jq >/dev/null 2>&1; then
    jq -nc --arg r "$reason" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
else
    printf '%s\n' "$reason" >&2
    exit 2
fi
exit 0
