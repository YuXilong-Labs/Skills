#!/bin/bash
# xcb-run.sh — xcodebuild 包装器：自动选目标设备 + rtk 风格精简输出
# Created by yuxilong on 2026/06/03
#
# 用法：
#   xcb-run.sh <xcodebuild 的所有参数>
#   例：xcb-run.sh build -scheme App -workspace App.xcworkspace
#       xcb-run.sh test  -scheme App -project App.xcodeproj
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

err() { printf '%s\n' "$*" >&2; }

if [ "$#" -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    err "用法: xcb-run.sh <xcodebuild 参数...>"
    err "示例: xcb-run.sh build -scheme App -workspace App.xcworkspace"
    [ "$#" -eq 0 ] && exit 64 || exit 0
fi

command -v xcodebuild >/dev/null 2>&1 || { err "未找到 xcodebuild（需安装 Xcode 命令行工具）"; exit 64; }

# ---- 判定是否需要 destination / 是否需要精简 ----
has_destination=0
action_needs_dest=0
for a in "$@"; do
    case "$a" in
        -destination) has_destination=1 ;;
        -destination=*) has_destination=1 ;;
        build|test|build-for-testing|test-without-building|analyze|archive|install)
            action_needs_dest=1 ;;
    esac
done

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
        err "缺少 $DEVICES_SH，回退 platform=macOS"
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

# ---- 原始日志落盘 ----
LOG_DIR="${TMPDIR:-/tmp}/wk-xcodebuild"
mkdir -p "$LOG_DIR"
RAW="$LOG_DIR/xcb-$(date +%Y%m%d-%H%M%S)-$$.log"

# ---- 组装并运行 ----
set -- "$@"
if [ -n "$DEST" ]; then
    err "▸ xcodebuild target: -destination '$DEST'"
    xcodebuild "$@" -destination "$DEST" > "$RAW" 2>&1
    rc=$?
else
    xcodebuild "$@" > "$RAW" 2>&1
    rc=$?
fi

# ---- 可选：xcbeautify 生成人类可读日志（不进 stdout）----
if [ "${WK_XCB_PRETTY:-0}" = "1" ] && command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify < "$RAW" > "${RAW%.log}.pretty.log" 2>/dev/null || true
fi

# ---- 是否需要精简：build/test 类才精简；信息类（-list/-version 等）直出 ----
if [ "$action_needs_dest" -eq 1 ] || [ "$has_destination" -eq 1 ]; then
    awk -v WMAX="${WK_XCB_WMAX:-30}" -v MAXBODY="${WK_XCB_MAXBODY:-240}" -f "$SUMMARIZE_AWK" "$RAW"
    printf '\n----\nexit code : %s\nraw log   : %s\n' "$rc" "$RAW"
    [ "${WK_XCB_PRETTY:-0}" = "1" ] && [ -f "${RAW%.log}.pretty.log" ] && \
        printf 'pretty log: %s\n' "${RAW%.log}.pretty.log"
else
    # 信息类命令：原样输出（通常很短且有用）
    cat "$RAW"
    printf '\n----\nexit code : %s\nraw log   : %s\n' "$rc" "$RAW"
fi

exit "$rc"
