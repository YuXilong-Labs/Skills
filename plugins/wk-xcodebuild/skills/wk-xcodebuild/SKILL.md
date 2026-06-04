---
name: wk-xcodebuild
description: |
  iOS/macOS 工程编译与测试的 xcodebuild / swift(SwiftPM) 智能包装工作流。
  当需要执行 xcodebuild 编译（build）、测试（test/build-for-testing）、归档（archive）、
  分析（analyze），或 swift build / swift test（Swift Package Manager）时使用本 Skill，
  而非直接运行裸 xcodebuild / swift build/test。
  xcodebuild 路径会自动检测本机 USB 真机并设为目标（无真机回退 My Mac）；
  swift 路径为本机构建、不选设备。两者都参考 rtk 的方式精简海量输出，只把关键信息
  （结果、error、链接/签名错误、测试失败用例、warning 去重计数）返回给 agent，
  完整日志落盘，显著减少上下文填充、节省 token。
  TRIGGER：用户要求编译/构建/跑测试/build/test/run on device/真机调试/swift build/swift test，
  或 agent 准备调用 xcodebuild 或 swift build/test 时。
---

# WK-Xcodebuild — xcodebuild 智能包装 Skill

## 目的

1. **目标设备自动化** — USB 真机优先，多台询问用户，无真机回退 My Mac。
2. **输出精简（rtk 风格）** — 千行 xcodebuild 输出 → 几十行关键摘要，省 token。
3. **自动启用（静默改写）** — PreToolUse Hook 检测到裸 `xcodebuild` 时，直接把命令
   改写为包装器调用（`allow` + `updatedInput`），无需 agent 重试一次；改写失败才回退 deny。

两端通用：Claude Code 与 Codex CLI 同一套脚本与 hook。

---

## 安装后脚本位置

| 安装方式 | 脚本目录 |
|---|---|
| install.sh → Claude | `~/.claude/scripts/wk-xcodebuild/` |
| install.sh → Codex | `~/.codex/scripts/wk-xcodebuild/` |
| 原生 plugin | `<plugin_root>/scripts/` |

核心脚本：`xcb-run.sh`（包装器）、`xcb-devices.sh`（设备检测）、`xcb-summarize.awk`（精简）、`xcb-guard.sh`（hook 守卫）。

install.sh 还会把 `xcb` 命令软链到 PATH（优先 `~/.local/bin`），即 `xcb` ≡ `xcb-run.sh`。

---

## 工作流

### 第 1 步：用包装器替代裸 xcodebuild

**任何 build/test 类 xcodebuild 调用都改用包装器**，参数完全相同。两种等价写法：

```bash
# 完整路径（最稳，非交互/任意 shell 都可用 —— agent 优先用这个）
~/.claude/scripts/wk-xcodebuild/xcb-run.sh build -scheme App -workspace App.xcworkspace

# 短命令 xcb（install.sh 已软链到 PATH，终端手动调用更顺手）
xcb build -scheme App -workspace App.xcworkspace
xcb test  -scheme App -project App.xcodeproj

# Swift Package Manager：首参 swift → 跑 SwiftPM（本机构建，不选真机）
xcb swift build -c release
xcb swift test --filter MyTests
```

> `xcb` 由 install.sh 软链到 PATH 可写目录（优先 `~/.local/bin`）。若 `command -v xcb`
> 找不到（该目录不在 PATH），用完整路径，或把 `~/.claude/scripts/wk-xcodebuild` 加入 PATH。

包装器自动：选目标设备 → 注入 `-destination` → 运行 → 原始日志落盘 → stdout 仅输出精简摘要。

> 若已显式传 `-destination`，包装器尊重用户指定，不再自动选设备。

### 第 2 步：处理"多台真机需选择"

当本机连接 **多台 USB 真机** 且未指定 `-destination`/`WK_XCB_DEST` 时，
`xcb-run.sh` 以退出码 **3** 返回设备清单（stderr 可读列表 + stdout JSON）。此时：

1. 解析设备清单，向用户展示候选（名称 + UDID + 系统版本）。
2. 询问用户选择哪一台。
3. 用 `WK_XCB_DEST="id=<用户选择的 UDID>"` 前缀重跑同一条命令。

```bash
WK_XCB_DEST="id=00008130-001929D40E8B803A" ~/.claude/scripts/wk-xcodebuild/xcb-run.sh build -scheme App -workspace App.xcworkspace
```

详见 `references/destination-selection.md`。

### 第 3 步：解读精简摘要

stdout 输出结构（详见 `references/output-filtering.md`）：

```
=== xcodebuild summary ===
result : ** BUILD FAILED **
counts : errors=2  warnings=5(unique=3)  linker=0  signing=0  test_failures=0
-- errors --
<编译错误 file:line: error: ...>
...
----
exit code : 65
raw log   : /tmp/wk-xcodebuild/xcb-...log
```

- **优先看 `result` 与 `counts`** 判断成败与问题规模。
- 失败时按 `-- errors -- / -- linker -- / -- code signing -- / -- test failures --` 分区定位。
- **需要完整上下文时再读 `raw log` 路径指向的文件**（按需 grep，不要整体读入）。

---

## 输入参数（透传给 xcodebuild）

本 Skill 不引入新参数语义，`xcb-run.sh` 后的参数即标准 xcodebuild 参数
（`build` / `test` / `-scheme` / `-workspace` / `-project` / `-configuration` / `-sdk` 等）。

### 控制用环境变量

| 变量 | 作用 |
|---|---|
| `WK_XCB_DEST` | 强制 `-destination` 值（如 `id=<UDID>` 或 `platform=macOS`） |
| `WK_XCB_BYPASS=1` | 逃生舱：让 Hook 放行本次裸 xcodebuild（不走包装器） |
| `WK_XCB_PRETTY=1` | 若装有 xcbeautify，额外生成 `*.pretty.log` 人类可读日志（不进 stdout） |
| `WK_XCB_WMAX` | warning 去重后最多展示条数（默认 30） |
| `WK_XCB_MAXBODY` | 摘要正文行数上限（默认 240） |
| `WK_XCB_NOSTATS=1` | 关闭 token 收益统计记录 |
| `WK_XCB_STATS_DIR` | 统计数据目录（默认 `~/.cache/wk-xcodebuild`） |

---

## token 收益统计

每次 build/test 运行后，包装器在页脚输出本次与累计节省的 token（`chars/4` 估算）：

```
token     : 原始 ~259102 → 摘要 ~672，本次省 ~258430 (99%)，累计省 ~396105
```

并把记录追加到 `~/.cache/wk-xcodebuild/stats.jsonl`。用 `xcb-gain` 查看累计收益：

```bash
xcb-gain              # 汇总：运行次数、原始/精简/累计节省 token、平均削减
xcb-gain --history    # 汇总 + 最近 N 次明细
xcb-gain --reset      # 清空统计
```

`WK_XCB_NOSTATS=1` 可关闭记录。

---

## 设备选择策略（摘要）

```
xcrun devicectl（精确区分 USB/WiFi）
  └─ transportType == "wired" 的真机 = USB 候选
       ├─ 恰好 1 台 → 直接用 id=<UDID>
       └─ 多台      → needs_user_choice，询问用户
  └─ 无 USB 真机 → 回退 platform=macOS
（devicectl 不可用时 xctrace 回退，无法区分 USB，取在线物理设备）
```

---

## 设计原则

- **只包装不改代码** — Skill 只负责选目标与精简输出，不修改用户工程。
- **token 优先** — stdout 只放精简摘要；完整日志落盘按需读取（rtk tee recovery）。
- **保守可逃生** — 误伤时 `WK_XCB_BYPASS=1` 直跑原始 xcodebuild。
- **证据可追** — 摘要附 `raw log` 路径，结论可回溯原始输出。

## 引用文档

- `references/destination-selection.md` — 设备检测细节、多设备处理、destination 取值
- `references/output-filtering.md` — 精简规则（保留/剥离清单）、摘要格式、token 收益
