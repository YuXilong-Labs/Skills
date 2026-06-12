#!/bin/bash
# xcb-result.sh — xcresult 结构化摘要：xcresulttool / xccov 输出 → 几十行权威摘要
# Created by yuxilong on 2026/06/12
#
# 用法（通常经 xcb-run.sh 子命令分发调用）：
#   xcb-result.sh result [--tests] [--path <xcresult>]   # 测试结果摘要
#   xcb-result.sh cov    [--path <xcresult>]             # 代码覆盖率摘要
#
# 为什么需要它（实测）：
#   - `xcresulttool get test-results tests` 原始 JSON ~155K 字符（~39K token）；
#   - 手工 `summary | head -n 80` 会截断关键字段（JSON 键按字母序，
#     devicesAndConfigurations 排最前，多设备时 result/testFailures 在 80 行之外）；
#   - `2>/dev/null` 吞掉路径错误，agent 无法区分"没结果"和"全过"。
#   本脚本输出完整、确定性的摘要，xcresulttool 计数对 XCTest / Swift Testing 统一权威。
#
# --path 缺省时自动定位最新 xcresult（包装器落盘目录优先，其次 DerivedData）。
# 未知选项静默忽略（兼容 hook 改写后残留的 xcresulttool 原生 flag，如 --compact）。
#
# 退出码：0 摘要成功（即使测试有失败）；64 用法/环境错误；65 xcresult 读取失败。

set -uo pipefail

err() { printf '%s\n' "$*" >&2; }

command -v jq >/dev/null 2>&1 || { err "xcb-result 需要 jq（brew install jq）"; exit 64; }
command -v xcrun >/dev/null 2>&1 || { err "未找到 xcrun（需 Xcode 命令行工具）"; exit 64; }

MODE="${1:-}"
case "$MODE" in
    result|cov) shift ;;
    *) err "用法: xcb-result.sh result [--tests] [--path <xcresult>] | cov [--path <xcresult>]"; exit 64 ;;
esac

XCR=""
WITH_TESTS=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --path)   XCR="${2:-}"; shift 2 || break ;;
        --path=*) XCR="${1#--path=}"; shift ;;
        --tests)  WITH_TESTS=1; shift ;;
        *) shift ;;   # 未知选项/参数：忽略（见文件头说明）
    esac
done

# ---- 缺省时定位最新 xcresult：包装器落盘目录优先，其次 DerivedData ----
if [ -z "$XCR" ]; then
    XCR="$(ls -td "${TMPDIR:-/tmp}/wk-xcodebuild"/*.xcresult \
                  "$HOME/Library/Developer/Xcode/DerivedData"/*/Logs/Test/*.xcresult 2>/dev/null | head -n 1)"
    [ -z "$XCR" ] && { err "未找到任何 .xcresult（可用 --path 指定）"; exit 65; }
fi
[ -e "$XCR" ] || { err "xcresult 不存在：$XCR"; exit 65; }

LOG_DIR="${TMPDIR:-/tmp}/wk-xcodebuild"
mkdir -p "$LOG_DIR"

# ---- token 收益统计（与 xcb-run.sh 同一 stats.jsonl，xcb-gain 汇总）----
STATS_DIR="${WK_XCB_STATS_DIR:-$HOME/.cache/wk-xcodebuild}"
record_stats() { # action result raw_tok sum_tok saved pct
    [ "${WK_XCB_NOSTATS:-0}" = "1" ] && return 0
    mkdir -p "$STATS_DIR" 2>/dev/null || return 0
    printf '{"ts":"%s","action":"%s","result":"%s","raw_tokens":%s,"summary_tokens":%s,"saved_tokens":%s,"reduction":%s}\n' \
        "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" "$3" "$4" "$5" "$6" >> "$STATS_DIR/stats.jsonl" 2>/dev/null || true
}

RAW_EXTRA=""   # --tests 时的 tests JSON，计入 raw 侧统计

emit_footer() { # action result summary_text raw_file
    local raw_chars extra_chars sum_chars raw_tok sum_tok saved pct
    raw_chars=$(wc -c < "$4" 2>/dev/null | tr -d ' '); raw_chars=${raw_chars:-0}
    if [ -n "$RAW_EXTRA" ] && [ -f "$RAW_EXTRA" ]; then
        extra_chars=$(wc -c < "$RAW_EXTRA" 2>/dev/null | tr -d ' ')
        raw_chars=$(( raw_chars + ${extra_chars:-0} ))
    fi
    sum_chars=${#3}
    raw_tok=$(( raw_chars / 4 )); sum_tok=$(( sum_chars / 4 ))
    saved=$(( raw_tok - sum_tok )); [ "$saved" -lt 0 ] && saved=0
    if [ "$raw_tok" -gt 0 ]; then pct=$(( saved * 100 / raw_tok )); else pct=0; fi
    record_stats "$1" "$2" "$raw_tok" "$sum_tok" "$saved" "$pct"
    printf '\n----\ntoken    : 原始 ~%s → 摘要 ~%s，本次省 ~%s (%s%%)\nraw json : %s\n' \
        "$raw_tok" "$sum_tok" "$saved" "$pct" "$4"
}

# ============================== result 模式 ==============================
if [ "$MODE" = "result" ]; then
    RAW="$LOG_DIR/xcresult-summary-$(date +%Y%m%d-%H%M%S)-$$.json"
    if ! xcrun xcresulttool get test-results summary --path "$XCR" > "$RAW" 2>"$RAW.err"; then
        err "xcresulttool 读取失败：$XCR"
        sed -n '1,5p' "$RAW.err" >&2 2>/dev/null
        exit 65
    fi
    rm -f "$RAW.err"

    summary="$(jq -r --arg xcr "$XCR" '
        "=== xcresult summary ===",
        "bundle  : \($xcr)",
        "result  : \(.result // "?")",
        "counts  : total=\(.totalTestCount // 0) passed=\(.passedTests // 0) failed=\(.failedTests // 0) skipped=\(.skippedTests // 0) expected_failures=\(.expectedFailures // 0)",
        "device  : \([(.devicesAndConfigurations // [])[] | .device | "\(.deviceName // "?") (\(.platform // "?") \(.osVersion // "?"))"] | unique | join(", "))",
        "duration: \(if .startTime and .finishTime then ((.finishTime - .startTime) * 10 | round / 10 | tostring) + "s" else "?" end)",
        (if ((.testFailures // []) | length) > 0 then
            "",
            "-- failures --",
            ((.testFailures // [])[] |
                "✘ \(.testName // .testIdentifierString // "?")  [\(.targetName // "?")]" +
                (if (.failureText // "") != "" then "\n    \((.failureText) | split("\n")[0])" else "" end))
        else empty end),
        (if ((.topInsights // []) | length) > 0 then
            "",
            "-- insights --",
            ((.topInsights // [])[] | "\(.impact // "info"): \((.text // "") | split("\n")[0])")
        else empty end)
    ' "$RAW" 2>/dev/null)"

    if [ -z "$summary" ]; then
        err "xcresult JSON 解析失败，原始输出：$RAW"
        exit 65
    fi

    # --tests：失败用例的 file:line 级明细（来自 test-results tests，原始 ~39K token）
    if [ "$WITH_TESTS" -eq 1 ]; then
        RAWT="$LOG_DIR/xcresult-tests-$(date +%Y%m%d-%H%M%S)-$$.json"
        RAW_EXTRA="$RAWT"
        if xcrun xcresulttool get test-results tests --path "$XCR" > "$RAWT" 2>/dev/null; then
            detail="$(jq -r '
                [.. | objects | select(.nodeType? == "Test Case")] as $cases |
                ([$cases[] | select(.result == "Failed")]) as $failed |
                "",
                "-- failed cases (\($failed | length) of \($cases | length)) --",
                ($failed[] |
                    "✘ \(.name // .nodeIdentifier // "?") \(.duration // "")",
                    ([.. | objects | select(.nodeType? == "Failure Message")][] | "    \(.name // "")"))
            ' "$RAWT" 2>/dev/null)"
            [ -n "$detail" ] && summary="$summary
$detail"
        fi
    fi

    printf '%s\n' "$summary"
    res="$(jq -r '.result // "?"' "$RAW" 2>/dev/null)"
    emit_footer "result" "$res" "$summary" "$RAW"
    exit 0
fi

# ============================== cov 模式 ==============================
RAW="$LOG_DIR/xccov-$(date +%Y%m%d-%H%M%S)-$$.json"
if ! xcrun xccov view --report --json "$XCR" > "$RAW" 2>"$RAW.err"; then
    err "xccov 读取失败（该 xcresult 可能未开启覆盖率，需 test 时加 -enableCodeCoverage YES）：$XCR"
    sed -n '1,5p' "$RAW.err" >&2 2>/dev/null
    exit 65
fi
rm -f "$RAW.err"

COV_WORST="${WK_XCB_COV_WORST:-10}"
summary="$(jq -r --arg xcr "$XCR" --argjson worst "$COV_WORST" '
    def pct: . * 1000 | round | . / 10;
    "=== coverage summary ===",
    "bundle  : \($xcr)",
    "overall : \((.lineCoverage // 0) | pct)%  (\(.coveredLines // 0)/\(.executableLines // 0) lines)",
    "",
    "-- targets --",
    ((.targets // [])[] | "\((.lineCoverage // 0) | pct)%\t\(.name // "?")"),
    (([(.targets // [])[].files[]? | select((.executableLines // 0) > 0)]
        | sort_by(.lineCoverage) | .[:$worst]) as $low |
     if ($low | length) > 0 then
        "",
        "-- lowest files (top \($low | length)) --",
        ($low[] | "\((.lineCoverage // 0) | pct)%\t\(.coveredLines // 0)/\(.executableLines // 0)\t\(.name // "?")")
     else empty end)
' "$RAW" 2>/dev/null)"

if [ -z "$summary" ]; then
    err "覆盖率 JSON 解析失败，原始输出：$RAW"
    exit 65
fi

printf '%s\n' "$summary"
overall="$(jq -r '(.lineCoverage // 0) * 1000 | round | . / 10' "$RAW" 2>/dev/null)"
emit_footer "cov" "${overall}%" "$summary" "$RAW"
exit 0
