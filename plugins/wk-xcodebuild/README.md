# wk-xcodebuild

xcodebuild 智能包装 Skill + PreToolUse Hook —— 自动选 USB 真机目标、rtk 风格精简输出，省 token。
同时兼容 **Claude Code** 与 **Codex CLI**。

## 能力

1. **目标设备自动化** — `devicectl` 精确识别 USB 真机（`transportType=wired`）并设为
   `-destination`；多台询问用户；无真机回退 `platform=macOS`。
2. **输出精简（rtk 风格）** — 千行 xcodebuild 输出 → 几十行关键摘要（结果 / error /
   链接 / 签名 / 测试失败 / warning 去重计数），完整日志落盘按需读取。
3. **自动启用（静默改写）** — PreToolUse Hook 检测到裸 `xcodebuild` 时，直接将命令
   改写为包装器调用（`allow` + `updatedInput`），agent 无感、不需重试；改写失败才回退 deny。

## 实测 token 收益

真实工程 **PoppoLive**（CocoaPods 大型 iOS App，真机 `build`，含 145 条近似链接告警）：

| 指标 | 原始 xcodebuild 输出 | wk-xcodebuild 摘要 | 削减 |
|---|---|---|---|
| 行数 | 5080 | ~24 | **99.5%** |
| 字符 | 1,036,410 | ~2,690 | **99.7%** |
| ~tokens（chars/4） | **~259,100** | **~672** | **99.7%** |

一次 build 为 agent 上下文节省 **~258,400 tokens**。关键收益来自：

- **剥离编译/链接任务噪声**（CompileC/Ld/CodeSign/环境 dump 等）。
- **链接告警按签名分组**：153 条 `ld: warning`（仅 `[N](file.o)` 不同）→ **3 组**
  （`145× / 7× / 1×`），保留首样例 + 次数，而非逐条刷屏。
- **warning 去重计数**、**失败优先**：错误/测试失败/签名问题永远保留，成功 build 仅几行摘要。

> 完整原始日志始终落盘（`raw log` 路径），需要细节时按需 grep，不重复填充上下文。

### 实时统计（xcb-gain）

每次运行会在页脚显示本次与累计节省，并记录到 `~/.cache/wk-xcodebuild/stats.jsonl`：

```
token     : 原始 ~259102 → 摘要 ~672，本次省 ~258430 (99%)，累计省 ~396105
```

用 `xcb-gain` 查看累计收益（类似 `rtk gain`）：

```bash
xcb-gain              # 运行次数、原始/精简/累计节省 token、平均削减
xcb-gain --history    # 汇总 + 最近 N 次明细
xcb-gain --reset      # 清空统计
```

`WK_XCB_NOSTATS=1` 关闭记录；`WK_XCB_STATS_DIR` 改数据目录。token 为 `chars/4` 估算。

## 组成

| 文件 | 作用 |
|---|---|
| `scripts/xcb-run.sh` | 包装器：选目标 + 跑 xcodebuild + 落盘 + 输出精简摘要 |
| `scripts/xcb-devices.sh` | USB 真机检测，输出 JSON |
| `scripts/xcb-summarize.awk` | rtk 风格输出精简（BSD-awk 兼容） |
| `scripts/xcb-guard.sh` | PreToolUse 守卫：裸 xcodebuild 静默改写为 xcb-run.sh（allow + updatedInput） |
| `scripts/xcb-stats.sh` | token 收益统计查看器（`xcb-gain`） |
| `scripts/.bin-links` | 声明 `xcb=xcb-run.sh`、`xcb-gain=xcb-stats.sh`，install.sh 据此软链命令到 PATH |
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
# 短命令 xcb（install.sh 已软链到 PATH，优先 ~/.local/bin）
xcb build -scheme App -workspace App.xcworkspace
xcb test  -scheme App -project App.xcodeproj

# 等价的完整路径（任意 shell 都可用）
~/.claude/scripts/wk-xcodebuild/xcb-run.sh build -scheme App -workspace App.xcworkspace

# 多真机：选定后强制目标
WK_XCB_DEST="id=<UDID>" xcb build -scheme App ...

# 逃生舱：直跑原始 xcodebuild（Hook 放行）
WK_XCB_BYPASS=1 xcodebuild -version
```

> `xcb` 找不到？说明软链目录不在 PATH。用完整路径，或把 `~/.claude/scripts/wk-xcodebuild` 加入 PATH。

或斜杠命令：`/wk-xcodebuild build -scheme App -workspace App.xcworkspace`。

## 环境变量

| 变量 | 作用 |
|---|---|
| `WK_XCB_DEST` | 强制 `-destination`（`id=<UDID>` / `platform=macOS`） |
| `WK_XCB_BYPASS=1` | Hook 放行本次裸 xcodebuild |
| `WK_XCB_PRETTY=1` | 额外生成 xcbeautify `*.pretty.log`（需装 xcbeautify） |
| `WK_XCB_WMAX` | warning 去重展示上限（默认 30） |
| `WK_XCB_MAXBODY` | 摘要正文行数上限（默认 240） |
