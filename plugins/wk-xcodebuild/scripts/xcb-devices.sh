#!/bin/bash
# xcb-devices.sh — 检测本机连接的 USB 真机，输出可被 xcb-run.sh 消费的 JSON
# Created by yuxilong on 2026/06/03
#
# 选择策略（与计划一致）：
#   USB 真机（devicectl transportType == "wired"）优先
#   → 多台则 needs_user_choice=true（由 Skill 询问用户）
#   → 无 USB 真机则回退 destination="platform=macOS"
#
# 设备来源优先级：
#   1) xcrun devicectl（Xcode 15+）：能精确区分 wired(USB) / localNetwork(WiFi)
#   2) xcrun xctrace 回退：仅能判断在线/离线，无法区分 USB，降级为"在线物理设备"候选
#
# 输出：单个 JSON 对象到 stdout。诊断信息到 stderr。
# 依赖：jq（解析/构造 JSON）。xctrace 文本解析用纯 bash（兼容 macOS BSD awk）。

set -uo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# 极简 JSON 字符串转义；空值输出 null
json_str() {
    local s="${1:-}"
    if [ -z "$s" ]; then printf 'null'; return; fi
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '"%s"' "$s"
}

# 物理设备 UDID 校验：25 位(8-16) 或 40 位 hex（排除 Mac 的 36 位 4-段 UUID）
is_device_udid() {
    [[ "$1" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}$ ]] || [[ "$1" =~ ^[0-9A-Fa-f]{40}$ ]]
}

# 解析 xctrace 输出，输出 TSV：udid<TAB>name<TAB>os，只取 "== Devices ==" 在线物理设备
# 纯 bash 字符串处理，避免 gawk-only 的 match(,,arr) 扩展。
xctrace_online_tsv() {
    have xcrun || return 1
    local raw; raw=$(xcrun xctrace list devices 2>/dev/null) || return 1
    local sec="" line udid namepart os
    while IFS= read -r line; do
        case "$line" in
            "== Devices =="*)         sec="online";  continue ;;
            "== Devices Offline =="*) sec="offline"; continue ;;
            "== Simulators =="*)      sec="sim";     continue ;;
            "== "*)                   sec="other";   continue ;;
            "")                       continue ;;
        esac
        [ "$sec" = "online" ] || continue
        case "$line" in *\(*\)) ;; *) continue ;; esac

        # udid = 最后一对括号内的内容
        udid="${line##*\(}"; udid="${udid%\)}"
        is_device_udid "$udid" || continue   # 排除 Mac/非设备行

        # name = 去掉尾部 " (udid)" 再去掉可能的 " (os)" 括号
        namepart="${line%\(*}"
        namepart="${namepart%"${namepart##*[![:space:]]}"}"   # rtrim
        os=""
        if [[ "$namepart" == *\) ]]; then
            os="${namepart##*\(}"; os="${os%\)}"
            namepart="${namepart%\(*}"
            namepart="${namepart%"${namepart##*[![:space:]]}"}"   # rtrim
        fi
        printf '%s\t%s\t%s\n' "$udid" "$namepart" "$os"
    done <<< "$raw"
}

# {udid: name} JSON map（用于给 devicectl 缺失的 name 补名）
xctrace_online_map() {
    have jq || { printf '{}'; return; }
    local tsv; tsv=$(xctrace_online_tsv) || { printf '{}'; return; }
    [ -z "$tsv" ] && { printf '{}'; return; }
    printf '%s\n' "$tsv" | jq -R -s -c '
        split("\n") | map(select(length>0) | split("\t"))
        | map({(.[0]): .[1]}) | add // {}' 2>/dev/null || printf '{}'
}

# ---- 路径 1：devicectl（精确区分 USB）----
detect_devicectl() {
    have jq || return 1
    have xcrun || return 1
    local tmp; tmp=$(mktemp)
    if ! xcrun devicectl list devices --json-output "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"; return 1
    fi

    # 选 transportType=="wired"（USB 直连）的真机；
    # UDID 从 *Hostnames 中形如 <UDID>.coredevice.local 的项提取。
    local devices_json
    devices_json=$(jq -c '
        [ .result.devices[]
          | select(.connectionProperties.transportType == "wired")
          | { name: (.deviceProperties.name // .name),
              platform: (.hardwareProperties.platform // "iOS"),
              model: (.hardwareProperties.deviceType // null),
              os: (.deviceProperties.osVersionNumber // null),
              udid: (
                ( (.connectionProperties.localHostnames // [])
                  + (.connectionProperties.potentialHostnames // []) )
                | map(sub("\\.coredevice\\.local$"; ""))
                | map(select(test("^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}$") or test("^[0-9A-Fa-f]{40}$")))
                | (.[0] // null) )
            }
          | select(.udid != null)
        ]' "$tmp" 2>/dev/null)
    rm -f "$tmp"
    [ -z "$devices_json" ] || [ "$devices_json" = "[]" ] && return 1

    # devicectl 的 name 常为 null，用 xctrace 在线列表按 UDID 补名字
    local map; map=$(xctrace_online_map)
    devices_json=$(jq -c --argjson m "$map" '
        map(. as $d
            | if ($d.name == null or $d.name == "") and ($m[$d.udid] != null)
              then .name = $m[$d.udid] else . end)' <<<"$devices_json" 2>/dev/null) \
        || return 1
    printf '%s' "$devices_json"
}

# ---- 路径 2：xctrace 回退（无法区分 USB，取在线物理设备）----
detect_xctrace() {
    have jq || return 1
    local tsv; tsv=$(xctrace_online_tsv) || return 1
    [ -z "$tsv" ] && { printf '[]'; return 0; }
    printf '%s\n' "$tsv" | jq -R -s -c '
        split("\n") | map(select(length>0) | split("\t"))
        | map({name: (.[1]|select(.!="")), platform: "iOS", model: null,
               os: (.[2]|select(.!="")), udid: .[0]})' 2>/dev/null || return 1
}

emit_json() {
    local source="$1" cu="$2" cn="$3" dest="$4" needs="$5" fb="$6" devices="$7"
    local count chosen="null"
    count=$(printf '%s' "$devices" | jq 'length' 2>/dev/null || echo 0)
    if [ -n "$cu" ]; then
        chosen=$(printf '{"name":%s,"udid":%s}' "$(json_str "$cn")" "$(json_str "$cu")")
    fi
    printf '{"source":%s,"usb_devices":%s,"count":%s,"chosen":%s,"destination":%s,"needs_user_choice":%s,"fallback_mac":%s}\n' \
        "$(json_str "$source")" "$devices" "$count" "$chosen" \
        "$(json_str "$dest")" "$needs" "$fb"
}

main() {
    local source="" devices=""

    devices=$(detect_devicectl) && source="devicectl"
    if [ -z "$source" ] || [ -z "$devices" ] || [ "$devices" = "[]" ]; then
        local xd; xd=$(detect_xctrace || true)
        if [ -n "$xd" ] && [ "$xd" != "[]" ]; then
            devices="$xd"; source="xctrace"
        fi
    fi

    if [ -z "$source" ] || [ -z "$devices" ] || [ "$devices" = "[]" ]; then
        emit_json "none" "" "" "platform=macOS" "false" "true" "[]"
        return 0
    fi

    local count udid name
    count=$(printf '%s' "$devices" | jq 'length' 2>/dev/null || echo 0)
    udid=$(printf '%s' "$devices" | jq -r '.[0].udid')
    name=$(printf '%s' "$devices" | jq -r '.[0].name // ""')

    if [ "$count" -eq 1 ]; then
        emit_json "$source" "$udid" "$name" "id=$udid" "false" "false" "$devices"
    else
        # 多台真机 → 交给 Skill 询问用户；destination 暂留第一台并标记 needs_user_choice
        emit_json "$source" "$udid" "$name" "id=$udid" "true" "false" "$devices"
    fi
}

main "$@"
