#!/bin/bash
# xcb-test-deps.sh — 测试前三方依赖预检（Texture / MMKV）
# Created by yuxilong on 2026/06/05
#
# 背景：跑 Tests 时，若工程依赖以下三方库且未做兼容处理，会让测试卡死或崩溃、
# 拖垮测试通过率。本脚本只读 Podfile.lock 做检测，命中则打印精简告警与补救指引，
# 不修改任何用户工程（符合本 Skill"只读不改"原则）。
#
#   1) Texture (AsyncDisplayKit) < 3.2.0
#      load 时构造函数在主线程创建 UIView → +[UIScreen initialize] 的 dispatch_once
#      等待 app 初始化上下文 → 主线程自锁，测试永久卡死。修复见 PR #2032
#      （3.2.0 起把 UIKit 访问从 constructor 挪到 destructor）。
#   2) MMKV
#      未在使用前 MMKV.initialize() 会 crash，导致测试失败。
#
# 用法：xcb-test-deps.sh [搜索起点目录...]
#   不传则用 $PWD。逐个起点向上回溯（最多 4 级）查找 Podfile.lock。
# 输出：命中时把告警写到 stdout（调用方决定路由）；未命中无输出。退出码恒为 0（非阻断）。

set -uo pipefail

MAX_UP=4

# ---- 定位 Podfile.lock：从给定起点逐级向上回溯 ----
find_lock() {
    local start="$1" dir
    dir="$(cd "$start" 2>/dev/null && pwd)" || return 1
    local i=0
    while [ "$i" -le "$MAX_UP" ]; do
        [ -f "$dir/Podfile.lock" ] && { printf '%s\n' "$dir/Podfile.lock"; return 0; }
        [ "$dir" = "/" ] && break
        dir="$(dirname "$dir")"
        i=$((i + 1))
    done
    return 1
}

LOCK=""
if [ "$#" -gt 0 ]; then
    for s in "$@"; do
        LOCK="$(find_lock "$s")" && break
    done
fi
[ -z "$LOCK" ] && LOCK="$(find_lock "$PWD")"
[ -z "$LOCK" ] && exit 0   # 非 CocoaPods 工程或找不到 lock，静默放行

# ---- 解析依赖版本 ----
# Podfile.lock 形如：  - Texture (3.1.0):  /  - MMKV (1.3.5):
pod_version() { # name → 版本号（取首个匹配），未命中输出空
    grep -m1 -E "^[[:space:]]*-[[:space:]]+$1[[:space:]]+\(" "$LOCK" 2>/dev/null \
        | sed -E "s/.*\(([0-9][0-9.]*).*/\1/"
}

# 语义版本 < 3.2.0 判定（仅比 major.minor，足够区分 Texture 修复线）
texture_at_risk() { # version
    local v="$1" major minor
    major="${v%%.*}"
    minor="$(printf '%s' "$v" | cut -d. -f2)"
    [ -z "$major" ] && return 1
    [ "$major" -lt 3 ] 2>/dev/null && return 0
    [ "$major" -eq 3 ] 2>/dev/null && [ "${minor:-0}" -lt 2 ] 2>/dev/null && return 0
    return 1
}

TEX_VER="$(pod_version Texture)"
MMKV_VER="$(pod_version MMKV)"

[ -z "$TEX_VER" ] && [ -z "$MMKV_VER" ] && exit 0

# ---- 输出告警 ----
emit() { printf '%s\n' "$*"; }

emit "=== 测试依赖预检（test preflight） ==="
emit "lock : $LOCK"

if [ -n "$TEX_VER" ]; then
    if texture_at_risk "$TEX_VER"; then
        emit "[!] Texture $TEX_VER — 含未修复的主线程自锁缺陷，跑 Tests 可能永久卡死。"
        emit "    根因：load 时构造函数在主线程建 UIView → UIScreen 初始化 dispatch_once 互锁。"
        emit "    首选修复：在 cocoapods-publish 里把 Texture 的 source/version 替换为含 PR #2032"
        emit "             的版本（私有 3.2.0 或 backport 的 3.1.0 tag），pod install 时集中生效。"
        emit "    fallback：Podfile post_install 给 Texture target 加 AS_INITIALIZE_FRAMEWORK_MANUALLY=1"
        emit "             并在 app/测试启动后手动 ASInitializeFrameworkMainThread()。"
    else
        emit "[ok] Texture $TEX_VER — 已 ≥3.2.0，含 PR #2032 修复，无需处理。"
    fi
fi

if [ -n "$MMKV_VER" ]; then
    emit "[!] MMKV $MMKV_VER — 使用前必须先 MMKV.initialize()，否则首次访问会 crash 致测试失败。"
    emit "    修复：在 main.mm（app 启动）或测试 bundle 的启动引导（principal class / +load /"
    emit "         XCTestObservation）里提前初始化，确保先于任何 MMKV 访问。"
fi

emit "详见 references/test-third-party-deps.md。本提示只读不改，请自行落补救。"
exit 0
