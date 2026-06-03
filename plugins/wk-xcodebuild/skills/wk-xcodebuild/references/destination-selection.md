# 目标设备选择细节

> 实现：`scripts/xcb-devices.sh`（被 `xcb-run.sh` 调用）。

## 检测来源与优先级

### 1) `xcrun devicectl list devices --json-output`（Xcode 15+，主路径）

能精确区分连接方式，关键字段在 `connectionProperties`：

| 字段 | 含义 |
|---|---|
| `transportType` | `wired` = **USB 直连**；`localNetwork` = WiFi；`null` = 未连接 |
| `pairingState` | `paired` 已配对 |
| `tunnelState` | `connected` / `disconnected` / `unavailable` |

**USB 真机判定** = `transportType == "wired"`。

设备 UDID（xcodebuild `-destination id=` 所需）从 `localHostnames` / `potentialHostnames`
中形如 `<UDID>.coredevice.local` 的项提取（`^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}$` 或 40 位 hex）。
devicectl 的 `name` 常为 null，用 `xctrace` 在线列表按 UDID 补名。

### 2) `xcrun xctrace list devices`（回退）

devicectl 不可用（低版本 Xcode）时回退。**无法区分 USB/WiFi**，只能区分在线
（`== Devices ==`）/ 离线（`== Devices Offline ==`），降级为"在线物理设备"候选，并排除 Mac 与模拟器。

## 选择逻辑

```
USB 候选数 == 1  → chosen = 该设备，destination = "id=<UDID>"
USB 候选数 > 1   → needs_user_choice = true（destination 暂留第一台）
USB 候选数 == 0  → fallback_mac = true，destination = "platform=macOS"
```

## `xcb-devices.sh` 输出 JSON

```json
{
  "source": "devicectl | xctrace | none",
  "usb_devices": [
    {"name": "iPhone15 Pro Max", "platform": "iOS", "model": "iPhone", "os": "26.3.1", "udid": "00008130-..."}
  ],
  "count": 1,
  "chosen": {"name": "...", "udid": "..."},
  "destination": "id=00008130-...",
  "needs_user_choice": false,
  "fallback_mac": false
}
```

## 多台真机处理

`xcb-run.sh` 在 `needs_user_choice == true` 且未指定目标时：

1. stderr 打印可读清单：`- <name>  [<UDID>]  <os>`
2. stdout 打印完整 JSON（供 Skill 解析）
3. 退出码 **3**

Skill 据此询问用户，拿到选择后用 `WK_XCB_DEST="id=<UDID>"` 重跑。

## destination 取值参考

| 场景 | `-destination` |
|---|---|
| 指定真机 | `id=<UDID>` |
| My Mac（回退） | `platform=macOS` |
| 用户显式指定 | 包装器尊重原 `-destination`，不覆盖 |

> 用 `id=<UDID>`（而非 `platform=iOS,id=...`）可避免 platform 与设备类型（iOS/iPadOS/tvOS）不匹配的报错。

## 边界与回退

- devicectl 与 xctrace 均不可用 / 无任何真机 → `platform=macOS`。
- 若工程不支持 macOS（纯 iOS scheme），Mac 回退会编译失败；此时摘要会显示对应 error，
  用户可改为指定模拟器 destination（`WK_XCB_DEST="platform=iOS Simulator,name=iPhone 15"`）重跑。
