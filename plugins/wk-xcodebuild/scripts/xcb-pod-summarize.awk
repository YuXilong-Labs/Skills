# xcb-pod-summarize.awk — rtk 风格 CocoaPods 输出精简器
# Created by yuxilong on 2026/06/12
#
# 适用：pod install / pod update / pod repo update / pod lib|spec lint。
# 只保留对 agent 决策有价值的信息：结果标记、依赖变更（Installing/Updating/Removing，
# 含 "was X.Y" 版本变化）、[!] 警告/错误块、lint 的 ERROR/WARN、Ruby 异常首行。
# Using（未变更的 pod）只计数不逐条展示；repo update / 下载 / git 噪声全部丢弃。
#
# 兼容 macOS BSD awk（同 xcb-summarize.awk：无 gawk 扩展）。
#
# 变量：-v CMAX=40（变更条目展示上限） -v MAXBODY=240（正文总行数上限）

BEGIN {
    CMAX   = (CMAX   == "" ? 40  : CMAX)
    MAXBODY= (MAXBODY== "" ? 240 : MAXBODY)
    ninst=0; nupd=0; nrm=0; nusing=0; nwarn=0; nerr=0; nlinterr=0; nlintwarn=0
    nchg=0; result=""; result_failed=0
    inbang=0
    linecount=0; bodycap=0
}

# ---- 结果标记 ----
/Pod installation complete!/ { line=$0; sub(/^[ \t]+/, "", line); result=line; next }
/passed validation/          { line=$0; sub(/^[ \t]+/, "", line); result=line; next }
/did not pass validation|did not pass .*spec/ {
    line=$0; sub(/^[ \t]+/, "", line); result=line; result_failed=1; next
}

# ---- [!] 块（警告 / 错误 / 依赖冲突树）----
# [!] 行 + 其后的缩进行（依赖冲突会附缩进的版本树），整块保留。
/^\[!\]/ {
    inbang=1; nwarn++
    if ($0 ~ /could not find compatible versions|Unable to|error|Error|failed/) { nerr++; nwarn-- }
    addbody($0); next
}
inbang==1 {
    if ($0 ~ /^[ \t]+[^ \t]/) { addbody($0); next }   # 缩进行 → 块内容，保留
    inbang=0                                            # 非缩进行 → 块结束，下沉
}

# ---- 依赖变更（pod install/update 的核心信息）----
/^Installing / { ninst++; collect_chg($0); next }
/^Updating /   { nupd++;  collect_chg($0); next }
/^Removing /   { nrm++;   collect_chg($0); next }
/^Using /      { nusing++; next }    # 未变更的 pod：只计数，不刷屏

# ---- lint 的分级条目（- ERROR | ... / - WARN | ...）----
/- ERROR \|/ { nlinterr++; addbody($0); next }
/- WARN[ \t]+\|/ { nlintwarn++; addbody($0); next }

# ---- Ruby 异常（CocoaPods crash）：保留异常首行，丢弃 backtrace ----
/^[A-Za-z:]+Error - / { nerr++; addbody($0); next }
/^Pod::/              { nerr++; addbody($0); next }

# 其余全部丢弃（Analyzing/Downloading/Generating、repo update 与 git 噪声、进度等）

function collect_chg(s) {
    nchg++
    if (nchg <= CMAX) chgbuf[nchg]=s
}
function addbody(s) { bodyorder[++nbody]=s }

END {
    if (result=="" && (nerr>0 || nlinterr>0)) {
        result="(failed — see [!] / errors below)"; result_failed=1
    } else if (result=="") {
        result="(no explicit marker — see exit code)"
    }

    printf("=== pod summary ===\n")
    printf("result : %s\n", result)
    printf("counts : installed=%d updated=%d removed=%d using=%d warnings=%d errors=%d",
           ninst, nupd, nrm, nusing, nwarn, nerr)
    if (nlinterr+nlintwarn > 0)
        printf("  lint_errors=%d lint_warnings=%d", nlinterr, nlintwarn)
    printf("\n")

    if (nchg > 0) {
        shown = (nchg < CMAX ? nchg : CMAX)
        printf("\n-- changes (showing %d of %d) --\n", shown, nchg)
        for (i=1; i<=shown; i++) {
            if (linecount>=MAXBODY) { bodycap=1; break }
            print chgbuf[i]; linecount++
        }
    }
    if (nbody > 0) {
        printf("\n-- warnings / errors --\n")
        for (i=1; i<=nbody; i++) {
            if (linecount>=MAXBODY) { bodycap=1; break }
            print bodyorder[i]; linecount++
        }
    }
    if (result_failed==0 && nchg==0 && nbody==0)
        printf("\n(no changes / warnings)\n")
    if (bodycap>0)
        printf("\n... output truncated (body line cap=%d reached) ...\n", MAXBODY)
}
