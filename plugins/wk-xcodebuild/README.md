# wk-xcodebuild

xcodebuild 智能包装 Skill + PreToolUse Hook —— 自动选 USB 真机目标、rtk 风格精简输出，省 token。
同时兼容 **Claude Code** 与 **Codex CLI**。

## 能力

1. **目标设备自动化** — `devicectl` 精确识别 USB 真机（`transportType=wired`）并设为
   `-destination`；多台询问用户；无真机回退 `platform=macOS`。
2. **输出精简（rtk 风格）** — 千行 xcodebuild 输出 → 几十行关键摘要（结果 / error /
   链接 / 签名 / 测试失败 / warning 去重计数），完整日志落盘按需读取。
3. **自动启用** — PreToolUse Hook 拦截裸 `xcodebuild`，引导改用包装器。

## 组成

| 文件 | 作用 |
|---|---|
| `scripts/xcb-run.sh` | 包装器：选目标 + 跑 xcodebuild + 落盘 + 输出精简摘要 |
| `scripts/xcb-devices.sh` | USB 真机检测，输出 JSON |
| `scripts/xcb-summarize.awk` | rtk 风格输出精简（BSD-awk 兼容） |
| `scripts/xcb-guard.sh` | PreToolUse 守卫：拦截裸 xcodebuild |
| `hooks/hooks.json` | 原生 plugin hook（`${PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_ROOT}`） |
| `hooks/settings-snippet.json` | install.sh → Claude 的 PreToolUse 合并片段 |
| `hooks/codex-settings-snippet.json` | install.sh → Codex 的 PreToolUse 合并片段 |
| `skills/wk-xcodebuild/SKILL.md` | Skill 主定义 + 工作流 |
| `commands/wk-xcodebuild.md` | 斜杠命令入口 |

## 安装

### 方式一：install.sh（双目标，Claude + Codex）

```bash
./install.sh wk-xcodebuild
```

脚本落到 `~/.claude/scripts/wk-xcodebuild/` 与 `~/.codex/scripts/wk-xcodebuild/`，
PreToolUse Hook 自动合并进 `~/.claude/settings.json` 与 `~/.codex/hooks.json`。

### 方式二：原生 plugin

- **Claude Code**：`/plugin marketplace add YuXilong-Labs/Skills` → 安装 `wk-xcodebuild`。
- **Codex CLI**：`codex plugin marketplace add YuXilong-Labs/Skills` → 安装 `wk-xcodebuild`。

## 用法

```bash
# 直接用包装器（参数同 xcodebuild）
~/.claude/scripts/wk-xcodebuild/xcb-run.sh build -scheme App -workspace App.xcworkspace
~/.claude/scripts/wk-xcodebuild/xcb-run.sh test  -scheme App -project App.xcodeproj

# 多真机：选定后强制目标
WK_XCB_DEST="id=<UDID>" ~/.claude/scripts/wk-xcodebuild/xcb-run.sh build -scheme App ...

# 逃生舱：直跑原始 xcodebuild（Hook 放行）
WK_XCB_BYPASS=1 xcodebuild -version
```

或斜杠命令：`/wk-xcodebuild build -scheme App -workspace App.xcworkspace`。

## 环境变量

| 变量 | 作用 |
|---|---|
| `WK_XCB_DEST` | 强制 `-destination`（`id=<UDID>` / `platform=macOS`） |
| `WK_XCB_BYPASS=1` | Hook 放行本次裸 xcodebuild |
| `WK_XCB_PRETTY=1` | 额外生成 xcbeautify `*.pretty.log`（需装 xcbeautify） |
| `WK_XCB_WMAX` | warning 去重展示上限（默认 30） |
| `WK_XCB_MAXBODY` | 摘要正文行数上限（默认 240） |
