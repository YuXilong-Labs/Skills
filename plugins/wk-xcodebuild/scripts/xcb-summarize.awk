# xcb-summarize.awk — rtk 风格 xcodebuild 输出精简器
# Created by yuxilong on 2026/06/03
#
# 设计参考 rtk-ai/rtk：Smart Filtering（剥离进度/编译任务噪声）、
# Grouping（按类别分区）、Dedup（重复 warning 折叠计数）、Failures-first（错误优先）。
#
# 只保留对 agent 决策有价值的信息：result 标记、编译 error、链接错误、
# 签名错误、测试失败用例、warning（去重+计数）。其余全部丢弃。
#
# 兼容 macOS BSD awk：不使用 gensub / 3 参数 match / asort 等 gawk 扩展。
# 桶名一律用字符串字面量传入（避免 awk 未初始化变量当作空串导致键冲突）。
#
# 变量：-v WMAX=30（warning 去重后最多展示条数） -v MAXBODY=240（正文总行数上限）

BEGIN {
    WMAX   = (WMAX   == "" ? 30  : WMAX)
    MAXBODY= (MAXBODY== "" ? 240 : MAXBODY)
    nerr=0; nwarn=0; nwuniq=0; ntestfail=0; nlink=0; nsign=0; nldwarn=0; nldwsig=0
    result=""; result_failed=0
    infail=0; inlink=0; infailtests=0
    linecount=0; bodycap=0
}

# ---- 结果标记 ----
/\*\* (BUILD|TEST|CLEAN|ARCHIVE|INSTALL|ANALYZE) (SUCCEEDED|FAILED) \*\*/ {
    line=$0; sub(/^[ \t]+/, "", line)
    result=line
    if (line ~ /FAILED/) result_failed=1
    next
}
# SwiftPM 成功标记（无 ** ** marker）：记标志，END 据有无失败定结果
/Build complete!/ { swiftok=1; next }

# ---- "The following build commands failed:" 块 ----
/^The following build commands failed:/ { infail=1; addbody("-- build commands failed --"); next }
infail==1 {
    if ($0 ~ /^[ \t]*$/) { infail=0; next }
    addbody($0); next
}

# ---- 链接错误块（Undefined symbols ...）----
/^Undefined symbols/ { inlink=1; nlink++; addbody("-- linker --"); addbody($0); next }
inlink==1 {
    if ($0 ~ /^[ \t]*$/) { inlink=0; next }
    addbody($0)
    if ($0 ~ /symbol\(s\) not found/) inlink=0
    next
}

# ---- 测试失败汇总块（Failing tests / Testing failed）：仅展示，不计数 ----
# 计数权威来源是 "Test Case ... failed"；此处块只为保留可读的失败用例清单。
/^Failing tests:/  { infailtests=1; addbody("-- failing tests --"); next }
/^Testing failed:/ { result_failed=1; if (result !~ /FAILED/) result="** TEST FAILED **"; infailtests=1; addbody($0); next }
infailtests==1 {
    if ($0 ~ /^[ \t]+[^ \t]/) { addbody($0); next }   # 缩进的失败用例条目 → 保留
    infailtests=0                                       # 非缩进行 → 结束块，下沉给后续规则
}

# ---- 链接告警（按签名分组，避免成百上千条近似行刷屏）----
# 必须在通用 `ld:` 规则之前，先把 `ld: warning:` 归到分组路径。
/(^|: )ld: warning: /  { collect_ldwarn($0); next }

# ---- 单行链接错误 / 签名 / 命令失败 ----
/(^|: )ld: /                           { collect_link($0); next }
/clang: error: linker command failed/  { collect_link($0); next }
/Code Sign(ing)? error|No signing certificate|requires a development team|No profiles for|Provisioning profile .*(expired|doesn't include|does not|not found)/ {
    collect_sign($0); next
}
/Command .* failed with (a )?(nonzero )?exit code|failed with exit code [0-9]/ {
    collect_err($0); next
}

# ---- 测试用例失败（XCTest 文本格式）----
/Test Case .* failed/    { collect_testfail($0); next }
/Test Suite .* failed/   { collect_testfail($0); next }
/Executed [0-9]+ test/    { collect_summary($0); next }

# ---- 测试用例失败（Swift Testing）----
# 前缀符号随运行方式变化（xcodebuild 下为私有区符号 􀢄，swift test 终端下为 ✘），
# 故匹配其独有文本短语，不依赖符号；"failed after N seconds" 仅 Swift Testing 使用
# （XCTest 是 "failed (N seconds)"），不会误伤。
/Test run with [0-9]+ test/                       { if ($0 ~ /failed/) result_failed=1; collect_summary($0); next }
/Test .* recorded an issue/                       { collect_testfail($0); next }
/(Test|Suite) .* failed after [0-9.]+ seconds/    { collect_testfail($0); next }

# ---- 编译 error / fatal error ----
/(^|: )(fatal error|error): /  { collect_err($0); next }
/^error: /                     { collect_err($0); next }

# ---- 噪声 warning：显式预编译模块 .pcm 找不到（无害，纯刷屏）----
# 形如 `warning: /var/folders/.../ExplicitPrecompiledModules/UIKit-XXX.pcm: No such file or directory`，
# 对决策无价值，直接丢弃（不计数、不展示），避免填充上下文。
/warning: .*\.pcm: No such file or directory/  { next }

# ---- 编译 warning（去重计数）----
/(^|: )warning: /  { collect_warn($0); next }
/^warning: /       { collect_warn($0); next }

# 其余全部丢弃（编译任务、环境 dump、进度等噪声）

# ---------- 收集函数（桶名用字面量）----------
function collect_err(s,   k) {
    nerr++; k="E:" s
    if (seen[k]++) return
    bstore["errbuf" SUBSEP (++nerrbuf)]=s
}
function collect_warn(s,   k) {
    nwarn++; k="W:" s
    if (seen[k]++) return
    nwuniq++
    if (nwuniq <= WMAX) bstore["warnbuf" SUBSEP (++nwarnbuf)]=s
}
function collect_link(s,   k) {
    k="L:" s
    if (seen[k]++) return
    nlink++; bstore["linkbuf" SUBSEP (++nlinkbuf)]=s
}
# 链接告警分组：把可变部分（[数字] / (内容) / 数字串）归一成签名后按签名聚合，
# 每签名只展示首个真实样例 + 出现次数，避免 N 百条近似 ld warning 刷屏。
function collect_ldwarn(s,   sig) {
    nldwarn++
    sig = s
    gsub(/\[[0-9]+\]/, "[N]", sig)
    gsub(/\([^()]*\)/, "(…)", sig)
    gsub(/[0-9]+/, "#", sig)
    if (!(sig in ldwseen)) { ldworder[++nldwsig]=sig; ldwexample[sig]=s }
    ldwseen[sig]++
}
function collect_sign(s,   k) {
    k="S:" s
    if (seen[k]++) return
    nsign++; bstore["signbuf" SUBSEP (++nsignbuf)]=s
}
function collect_testfail(s) {
    ntestfail++; bstore["tfbuf" SUBSEP (++ntfbuf)]=s
}
function collect_summary(s) {
    bstore["sumbuf" SUBSEP (++nsumbuf)]=s
}
# 块内行：保持多行结构，按插入序进 body 缓冲
function addbody(s) { bodyorder[++nbody]=s }

END {
    if (result=="" && (nerr>0 || nlink>0 || nsign>0 || ntestfail>0)) {
        result = (TOOL=="swift" ? "SwiftPM 失败（见下方 errors / test failures）" \
                                : "(no explicit result marker — see errors below)")
        result_failed=1
    } else if (result=="" && swiftok==1) {
        result="Build complete! (SwiftPM)"
    } else if (result=="") {
        result = (TOOL=="swift" ? "(SwiftPM：无 Build complete! 标记，见 exit code)" \
                                : "(unknown — no BUILD/TEST marker found)")
    }

    printf("=== xcodebuild summary ===\n")
    printf("result : %s\n", result)
    printf("counts : errors=%d  warnings=%d(unique=%d)  linker=%d  signing=%d  test_failures=%d  ld_warnings=%d(grouped=%d)\n",
           nerr, nwarn, nwuniq, nlink, nsign, ntestfail, nldwarn, nldwsig)

    printed=0
    printed += render_sum()
    printed += render_bucket("errbuf",  nerrbuf,  "-- errors --")
    printed += render_bucket("linkbuf", nlinkbuf, "-- linker (errors) --")
    printed += render_bucket("signbuf", nsignbuf, "-- code signing --")
    printed += render_bucket("tfbuf",   ntfbuf,   "-- test failures --")
    printed += render_body()
    printed += render_ldwarn()
    printed += render_bucket("warnbuf", nwarnbuf,
                 sprintf("-- warnings (unique, showing %d of %d) --",
                         (nwuniq<WMAX?nwuniq:WMAX), nwuniq))

    if (result_failed==0 && printed==0)
        printf("\n(no errors/warnings — build clean)\n")
    if (bodycap>0)
        printf("\n... output truncated (body line cap=%d reached) ...\n", MAXBODY)
}

function render_sum(   i) {
    if (nsumbuf+0==0) return 0
    printf("\n-- test summary --\n")
    for (i=1;i<=nsumbuf;i++) print bstore["sumbuf" SUBSEP i]
    return 1
}
function render_ldwarn(   i, sig) {
    if (nldwsig+0==0) return 0
    printf("\n-- linker warnings (grouped, %d 类 / 共 %d 条) --\n", nldwsig, nldwarn)
    for (i=1;i<=nldwsig;i++) {
        if (linecount>=MAXBODY) { bodycap=1; return 1 }
        sig=ldworder[i]
        printf("%5d×  %s\n", ldwseen[sig], ldwexample[sig]); linecount++
    }
    return 1
}
function render_bucket(name, n, header,   i) {
    if (n+0==0) return 0
    printf("\n%s\n", header)
    for (i=1;i<=n;i++) {
        if (linecount>=MAXBODY) { bodycap=1; return 1 }
        print bstore[name SUBSEP i]; linecount++
    }
    return 1
}
function render_body(   i) {
    if (nbody+0==0) return 0
    for (i=1;i<=nbody;i++) {
        if (linecount>=MAXBODY) { bodycap=1; return 1 }
        print bodyorder[i]; linecount++
    }
    return 1
}
