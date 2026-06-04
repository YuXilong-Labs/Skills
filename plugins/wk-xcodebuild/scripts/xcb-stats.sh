#!/bin/bash
# xcb-stats.sh — 展示 wk-xcodebuild 累计 token 收益（类似 rtk gain）
# Created by yuxilong on 2026/06/04
#
# 用法：
#   xcb-gain              汇总：运行次数、原始/精简/累计节省 token、平均削减
#   xcb-gain --history    汇总 + 最近若干次明细
#   xcb-gain --reset      清空统计
#
# 数据源：${WK_XCB_STATS_DIR:-~/.cache/wk-xcodebuild}/stats.jsonl（由 xcb-run.sh 追加）。

set -uo pipefail

STATS_DIR="${WK_XCB_STATS_DIR:-$HOME/.cache/wk-xcodebuild}"
STATS_FILE="$STATS_DIR/stats.jsonl"
HIST_N="${WK_XCB_HIST_N:-10}"

mode="summary"
case "${1:-}" in
    --history|-H) mode="history" ;;
    --reset)      rm -f "$STATS_FILE" && echo "已清空 wk-xcodebuild 统计"; exit 0 ;;
    --help|-h)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ ! -f "$STATS_FILE" ] || [ ! -s "$STATS_FILE" ]; then
    echo "暂无统计数据 —— 用 xcb 跑过 build/test 后再看（数据文件：${STATS_FILE}）"
    exit 0
fi

# 千分位（纯 awk，兼容 BSD）
commafy() { printf '%s' "${1:-0}" | awk '{x=$0;n=length(x);s="";for(i=1;i<=n;i++){s=s substr(x,i,1);if((n-i)%3==0&&i<n)s=s","}print s}'; }

# 用 awk 单遍聚合（不依赖 jq）：提取每行 raw/summary/saved 字段累加
read -r RUNS RAW SUM SAVED OKN FAILN <<EOF
$(awk '
function f(line,key,   v){ if(match(line,"\""key"\":")){ v=substr(line,RSTART+length(key)+3); gsub(/[^0-9].*/,"",v); return v+0 } return 0 }
{ runs++; r+=f($0,"raw_tokens"); s+=f($0,"summary_tokens"); v+=f($0,"saved_tokens");
  if($0 ~ /"result":"success"/) ok++; else fail++ }
END{ printf "%d %d %d %d %d %d", runs, r, s, v, ok, fail }
' "$STATS_FILE")
EOF

pct=0; [ "$RAW" -gt 0 ] && pct=$(( SAVED * 100 / RAW ))
avg=0; [ "$RUNS" -gt 0 ] && avg=$(( SAVED / RUNS ))

echo "wk-xcodebuild — token 收益统计"
echo "──────────────────────────────────────────"
printf "  运行次数      : %s  (成功 %s / 失败 %s)\n" "$(commafy "$RUNS")" "$(commafy "$OKN")" "$(commafy "$FAILN")"
printf "  原始输出      : ~%s tokens\n" "$(commafy "$RAW")"
printf "  精简后        : ~%s tokens\n" "$(commafy "$SUM")"
printf "  累计节省      : ~%s tokens  (%s%%)\n" "$(commafy "$SAVED")" "$pct"
printf "  平均每次节省  : ~%s tokens\n" "$(commafy "$avg")"
echo "  （token 为 chars/4 估算）"

if [ "$mode" = "history" ]; then
    echo
    echo "最近 $HIST_N 次："
    tail -n "$HIST_N" "$STATS_FILE" | awk '
    function f(line,key,   v){ if(match(line,"\""key"\":")){ v=substr(line,RSTART+length(key)+3); gsub(/[^0-9].*/,"",v); return v+0 } return 0 }
    function sv(line,key,   v){ if(match(line,"\""key"\":\"")){ v=substr(line,RSTART+length(key)+4); gsub(/".*/,"",v); return v } return "?" }
    { printf "  %s  %-7s %-7s  %8d → %-6d (-%d%%)\n", sv($0,"ts"), sv($0,"action"), sv($0,"result"), f($0,"raw_tokens"), f($0,"summary_tokens"), f($0,"reduction") }'
fi
