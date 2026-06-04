---
description: xcodebuild 智能包装 — 自动选 USB 真机目标（无则回退 Mac）并精简编译/测试输出节省 token
mode: skill
skill_file: skills/wk-xcodebuild/SKILL.md
---

# /wk-xcodebuild

以 wk-xcodebuild 包装器执行 xcodebuild 编译/测试：自动选择 USB 真机目标，
无真机时回退 My Mac，并对输出做 rtk 风格精简。

> 多数情况下你**不需要手动调用**此命令：PreToolUse Hook 会在你准备运行裸
> `xcodebuild` 时自动拦截并引导改用包装器。此命令用于显式触发工作流。

## 用法

```
/wk-xcodebuild <xcodebuild 参数>
```

参数与标准 xcodebuild 完全一致。

> 终端手动调用可用 install.sh 软链的短命令 `xcb`（≡ `xcb-run.sh`），
> 如 `xcb build -scheme App ...`；找不到时用完整路径 `~/.claude/scripts/wk-xcodebuild/xcb-run.sh`。

## 使用示例

### 编译（自动选目标）

```
/wk-xcodebuild build -scheme App -workspace App.xcworkspace
```

### 测试

```
/wk-xcodebuild test -scheme App -project App.xcodeproj
```

### 指定真机（跳过自动选择）

```
/wk-xcodebuild build -scheme App -destination 'id=00008130-001929D40E8B803A'
```

### 多台真机时（先看清单再选）

包装器返回退出码 3 + 设备清单 → 选定后：

```
WK_XCB_DEST="id=<UDID>" /wk-xcodebuild build -scheme App -workspace App.xcworkspace
```

### 自然语言

```
/wk-xcodebuild 帮我在真机上编译这个工程
/wk-xcodebuild 跑一下单元测试，输出精简点
```

## 输出

精简摘要（结果 + 计数 + 分区错误/警告）+ 页脚（退出码 + 原始日志路径）。
完整日志按需从 `raw log` 路径读取。

## 环境变量

- `WK_XCB_DEST` — 强制 destination（`id=<UDID>` 或 `platform=macOS`）
- `WK_XCB_BYPASS=1` — 让 Hook 放行裸 xcodebuild
- `WK_XCB_PRETTY=1` — 额外生成 xcbeautify 美化日志（需装 xcbeautify）

$ARGUMENTS
