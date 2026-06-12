#!/bin/bash
# xcb-run.sh — xcodebuild 包装器：自动选目标设备 + rtk 风格精简输出
# Created by yuxilong on 2026/06/03
#
# 用法：
#   xcb-run.sh <xcodebuild 的所有参数>            # 默认 xcodebuild
#   xcb-run.sh swift <swift 的所有参数>           # 首参 swift → 跑 SwiftPM
#   xcb-run.sh result [--tests] [--path <xcresult>]  # xcresult 测试结果摘要（xcb-result.sh）
#   xcb-run.sh cov    [--path <xcresult>]            # 覆盖率摘要（xcb-result.sh）
#   例：xcb-run.sh build -scheme App -workspace App.xcworkspace
#       xcb-run.sh test  -scheme App -project App.xcodeproj
#       xcb-run.sh swift build -c release
#       xcb-run.sh swift test --filter MyTests
#   注：swift（SwiftPM）本机构建，不做真机选择；仅精简输出 + 统计。
#
# test 类动作（test / test-without-building）若未显式传 -resultBundlePath，
# 自动注入落盘路径，并在摘要末尾追加 xcresult 权威分区（xcresulttool 计数对
# XCTest / Swift Testing 统一，补文本正则的盲区）。WK_XCB_NO_XCRESULT=1 关闭。
#
# 行为：
#   1) 若参数未含 -destination 且是 build/test 类操作：
#        调用 xcb-devices.sh 选目标 → USB 真机优先，无真机回退 platform=macOS。
#        多台真机时打印清单并以退出码 3 退出，交由 Skill 询问用户后用
#        WK_XCB_DEST="id=<UDID>" 重跑。
#   2) 运行 xcodebuild，完整原始输出落盘（rtk tee recovery）。
#   3) stdout 只输出 awk 精简摘要（token 优化的唯一来源），并附原始日志路径。
#
# 环境变量：
#   WK_XCB_DEST     强制 -destination 值（如 "id=00008130-..." 或 "platform=macOS"）
#   WK_XCB_PRETTY=1 若装有 xcbeautify，额外生成 *.pretty.log 人类可读日志（不进 stdout）
#   WK_XCB_RAW_LINES  原始日志在摘要无错误时也附带的尾部行数（默认 0）
#
# 退出码：透传 xcodebuild 的退出码；目标选择需用户介入时为 3；用法错误为 64。

set -uo pipefail

# 解析自身真实目录（兼容经 PATH 上的符号链接调用，如 ~/.local/bin/xcb → xcb-run.sh），
# 否则 SCRIPT_DIR 会指向软链所在目录而找不到同级的 xcb-devices.sh / xcb-summarize.awk。
_src="${BASH_SOURCE[0]}"
while [ -h "$_src" ]; do
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$_src")" && pwd)"
DEVICES_SH="$SCRIPT_DIR/xcb-devices.sh"
SUMMARIZE_AWK="$SCRIPT_DIR/xcb-summarize.awk"
TESTDEPS_SH="$SCRIPT_DIR/xcb-test-deps.sh"
RESULT_SH="$SCRIPT_DIR/xcb-result.sh"

err() { printf '%s\n' "$*" >&2; }

# ---- token 收益统计 ----
# 每次 build/test 记录"原始输出 vs 精简摘要"的估算 token（chars/4），落 JSONL，
# 供 xcb-stats.sh（xcb-gain）汇总。WK_XCB_NOSTATS=1 关闭；WK_XCB_STATS_DIR 改目录。
STATS_DIR="${WK_XCB_STATS_DIR:-$HOME/.cache/wk-xcodebuild}"
STATS_FILE="$STATS_DIR/stats.jsonl"

record_stats() { # action result raw_tok sum_tok saved pct
    [ "${WK_XCB_NOSTATS:-0}" = "1" ] && return 0
    mkdir -p "$STATS_DIR" 2>/dev/null || return 0
    printf '{"ts":"%s","action":"%s","result":"%s","raw_tokens":%s,"summary_tokens":%s,"saved_tokens":%s,"reduction":%s}\n' \
        "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" "$3" "$4" "$5" "$6" >> "$STATS_FILE" 2>/dev/null || true
}

# 累计已省 token（含本次，record 之后调用）
cumulative_saved() {
    [ -f "$STATS_FILE" ] || { printf '0'; return; }
    awk -F'"saved_tokens":' '{n=$2; gsub(/[^0-9].*/,"",n); s+=n} END{printf "%d", s+0}' "$STATS_FILE" 2>/dev/null || printf '0'
}

if [ "$#" -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    err "用法: xcb-run.sh <xcodebuild 参数...>"
    err "示例: xcb-run.sh build -scheme App -workspace App.xcworkspace"
    [ "$#" -eq 0 ] && exit 64 || exit 0
fi

# ---- 子命令分发：result / cov → xcb-result.sh（xcresult 结构化摘要）----
case "${1:-}" in
    result|cov)
        [ -x "$RESULT_SH" ] || { err "缺少 $RESULT_SH"; exit 64; }
        exec "$RESULT_SH" "$@" ;;
esac

# ---- 工具分发：默认 xcodebuild；首参为 swift 则跑 SwiftPM（swift build/test）----
TOOL="xcodebuild"
if [ "${1:-}" = "swift" ]; then
    TOOL="swift"; shift
fi
command -v "$TOOL" >/dev/null 2>&1 || { err "未找到 ${TOOL}（xcodebuild 需 Xcode 命令行工具；swift 需 Swift 工具链）"; exit 64; }

# ---- 判定是否需要 destination / 是否需要精简 ----
# xcodebuild：build/test 类需选目标设备并精简；swift：本机构建无需设备，build/test 仅精简。
has_destination=0
action_needs_dest=0
needs_summarize=0
is_test_action=0
wants_xcresult=0
has_result_bundle=0
user_xcresult=""
prev_arg=""
action_verb="build"
if [ "$TOOL" = "swift" ]; then
    for a in "$@"; do
        case "$a" in
            build) needs_summarize=1; action_verb="$a" ;;
            test) needs_summarize=1; is_test_action=1; action_verb="$a" ;;
        esac
    done
else
    for a in "$@"; do
        [ "$prev_arg" = "-resultBundlePath" ] && user_xcresult="$a"
        case "$a" in
            -destination) has_destination=1 ;;
            -destination=*) has_destination=1 ;;
            -resultBundlePath) has_result_bundle=1 ;;
            build|analyze|archive|install)
                action_needs_dest=1; needs_summarize=1; action_verb="$a" ;;
            test|test-without-building)
                # 这两类动作产出测试结果，跑完用 xcresult 做权威摘要
                action_needs_dest=1; needs_summarize=1; is_test_action=1
                wants_xcresult=1; action_verb="$a" ;;
            build-for-testing)
                action_needs_dest=1; needs_summarize=1; is_test_action=1; action_verb="$a" ;;
        esac
        prev_arg="$a"
    done
fi

# ---- 选择目标设备 ----
DEST=""
choose_dest=0
if [ "$has_destination" -eq 0 ] && [ "$action_needs_dest" -eq 1 ]; then
    if [ -n "${WK_XCB_DEST:-}" ]; then
        DEST="$WK_XCB_DEST"
    else
        choose_dest=1
    fi
fi

if [ "$choose_dest" -eq 1 ]; then
    if [ ! -x "$DEVICES_SH" ]; then
        err "缺少 ${DEVICES_SH}，回退 platform=macOS"
        DEST="platform=macOS"
    else
        devjson="$("$DEVICES_SH" 2>/dev/null)"
        needs_choice="$(printf '%s' "$devjson" | jq -r '.needs_user_choice // false' 2>/dev/null)"
        if [ "$needs_choice" = "true" ]; then
            # 多台 USB 真机 → 交给 Skill / 用户选择
            err "检测到多台 USB 真机，请选择其一后用 WK_XCB_DEST=\"id=<UDID>\" 重跑："
            printf '%s\n' "$devjson" | jq -r '.usb_devices[] | "  - \(.name // "?")  [\(.udid)]  \(.os // "")"' >&2
            printf '%s\n' "$devjson"   # 同时把 JSON 给 Skill 解析
            exit 3
        fi
        DEST="$(printf '%s' "$devjson" | jq -r '.destination // "platform=macOS"' 2>/dev/null)"
        [ -z "$DEST" ] || [ "$DEST" = "null" ] && DEST="platform=macOS"
    fi
fi

# ---- 测试前三方依赖预检（Texture/MMKV 致测试卡死/崩溃）----
# 仅 test 类动作触发；只读 Podfile.lock，命中则把告警注入摘要顶部（agent 可见），不改工程。
# WK_XCB_NO_TESTDEPS=1 关闭。
PREFLIGHT=""
if [ "$is_test_action" -eq 1 ] && [ "${WK_XCB_NO_TESTDEPS:-0}" != "1" ] && [ -x "$TESTDEPS_SH" ]; then
    # 搜索起点：-workspace/-project 所在目录 + 当前目录（脚本自身再向上回溯）
    ws_dir=""
    prev=""
    for a in "$@"; do
        case "$prev" in
            -workspace|-project) ws_dir="$(cd "$(dirname "$a")" 2>/dev/null && pwd)" ;;
        esac
        prev="$a"
    done
    PREFLIGHT="$("$TESTDEPS_SH" ${ws_dir:+"$ws_dir"} "$PWD" 2>/dev/null)"
    [ -n "$PREFLIGHT" ] && printf '%s\n' "$PREFLIGHT" >&2
fi

# ---- 原始日志落盘 ----
LOG_DIR="${TMPDIR:-/tmp}/wk-xcodebuild"
mkdir -p "$LOG_DIR"
RAW="$LOG_DIR/xcb-$(date +%Y%m%d-%H%M%S)-$$.log"

# ---- xcresult 注入（仅 test / test-without-building）----
# xcresulttool 的计数对 XCTest / Swift Testing 统一权威，跑完追加到摘要，
# 补文本正则识别不到 Swift Testing 失败标记的盲区。WK_XCB_NO_XCRESULT=1 关闭。
XCRESULT=""
if [ "$wants_xcresult" -eq 1 ] && [ "${WK_XCB_NO_XCRESULT:-0}" != "1" ] && [ "$TOOL" = "xcodebuild" ]; then
    if [ "$has_result_bundle" -eq 1 ]; then
        XCRESULT="$user_xcresult"   # 用户已显式指定 → 尊重其路径，仅用于事后摘要
    else
        XCRESULT="$LOG_DIR/xcb-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
        set -- "$@" -resultBundlePath "$XCRESULT"
    fi
fi

# ---- 组装并运行 ----
set -- "$@"
if [ -n "$DEST" ]; then
    err "▸ ${TOOL} target: -destination '$DEST'"
    "$TOOL" "$@" -destination "$DEST" > "$RAW" 2>&1
    rc=$?
else
    "$TOOL" "$@" > "$RAW" 2>&1
    rc=$?
fi

# ---- 可选：xcbeautify 生成人类可读日志（不进 stdout）----
if [ "${WK_XCB_PRETTY:-0}" = "1" ] && command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify < "$RAW" > "${RAW%.log}.pretty.log" 2>/dev/null || true
fi

# ---- 是否需要精简：build/test 类才精简；信息类（-list/-version 等）直出 ----
if [ "$needs_summarize" -eq 1 ]; then
    summary="$(awk -v WMAX="${WK_XCB_WMAX:-30}" -v MAXBODY="${WK_XCB_MAXBODY:-240}" -v TOOL="$TOOL" -f "$SUMMARIZE_AWK" "$RAW")"

    # ---- xcresult 权威分区（test 类动作跑完追加）----
    # 子摘要自带页脚（---- 之后），截掉避免双页脚；统计由本脚本统一记一次。
    if [ -n "$XCRESULT" ] && [ -e "$XCRESULT" ] && [ -x "$RESULT_SH" ]; then
        xcres_digest="$(WK_XCB_NOSTATS=1 "$RESULT_SH" result --path "$XCRESULT" 2>/dev/null \
                        | awk '/^----$/{exit} {print}')"
        # 测试根本没跑起来（如 scheme 错误）时 bundle 是空壳，分区只有噪声 → 不追加
        case "$xcres_digest" in *"result  : unknown"*) xcres_digest="" ;; esac
        [ -n "$xcres_digest" ] && summary="$summary

$xcres_digest"
    fi

    # 测试预检告警置顶（含 Texture/MMKV 时），确保 agent 在摘要里第一眼看到
    [ -n "$PREFLIGHT" ] && printf '%s\n\n' "$PREFLIGHT"
    printf '%s\n' "$summary"

    # token 收益（chars/4 估算）
    raw_chars=$(wc -c < "$RAW" 2>/dev/null | tr -d ' '); raw_chars=${raw_chars:-0}
    sum_chars=${#summary}
    raw_tok=$(( raw_chars / 4 )); sum_tok=$(( sum_chars / 4 ))
    saved=$(( raw_tok - sum_tok )); [ "$saved" -lt 0 ] && saved=0
    if [ "$raw_tok" -gt 0 ]; then pct=$(( saved * 100 / raw_tok )); else pct=0; fi
    [ "$rc" -eq 0 ] && res="success" || res="fail"
    record_stats "$action_verb" "$res" "$raw_tok" "$sum_tok" "$saved" "$pct"

    printf '\n----\nexit code : %s\n' "$rc"
    printf 'token     : 原始 ~%s → 摘要 ~%s，本次省 ~%s (%s%%)，累计省 ~%s\n' \
        "$raw_tok" "$sum_tok" "$saved" "$pct" "$(cumulative_saved)"
    printf 'raw log   : %s\n' "$RAW"
    [ "${WK_XCB_PRETTY:-0}" = "1" ] && [ -f "${RAW%.log}.pretty.log" ] && \
        printf 'pretty log: %s\n' "${RAW%.log}.pretty.log"
else
    # 信息类命令：原样输出（通常很短且有用），不计入统计
    cat "$RAW"
    printf '\n----\nexit code : %s\nraw log   : %s\n' "$rc" "$RAW"
fi

exit "$rc"
