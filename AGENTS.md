# AGENTS.md

面向 **Codex CLI**（及兼容 Agent Skills 标准的工具）的项目说明。
Claude Code 用户请参见 `CLAUDE.md`，二者内容对齐。

## 项目概述

iOS/macOS 开发的可安装 Skill 集合。每个 Skill 是结构化 prompt 工作流，
通过 `/wk-<name>` 调用或按 description 隐式触发，执行代码分析/构建/审查等任务。

## 架构

仓库采用"独立 Plugin"设计。每个 plugin 同时提供 Claude Code 与 Codex 两套清单：

```
plugins/<name>/
├── .claude-plugin/plugin.json   # Claude Code 清单
├── .codex-plugin/plugin.json    # Codex 清单（skills/hooks/interface）
├── skills/<name>/SKILL.md        # Skill 主定义（name + description + 工作流）
├── skills/<name>/references/      # 详细参考文档
├── commands/<name>.md             # 斜杠命令入口
├── hooks/hooks.json               # （含 hook 的 plugin）原生 plugin hook
└── scripts/                       # 辅助脚本
```

- Codex Marketplace 目录：根 `.agents/plugins/marketplace.json`，`source.path` 指向 `./plugins/<name>`。
- Codex 从 `~/.codex/skills/` 发现 SKILL.md；hook 配置在 `~/.codex/hooks.json` 或 plugin 的 `hooks/hooks.json`。

## 安装

### 原生 Codex Marketplace（推荐）

```bash
codex plugin marketplace add YuXilong-Labs/Skills   # 或在仓库根目录：codex plugin marketplace add ./
codex plugin list
codex plugin add wk-xcodebuild@yuxilong-skills
```

原生通道编入 **10 个 skill 类 plugin**。`ios-dev-rules`（规则类，Codex plugin 无 rules 字段）
与 `ios-blocked-words-hook`（hook 跨 plugin 依赖脚本）不走原生通道，请用 install.sh。

### install.sh（通用，双目标）

```bash
./install.sh                  # 安装全部到 ~/.claude 与 ~/.codex
./install.sh wk-xcodebuild    # 安装指定 plugin
./install.sh --list
./install.sh --uninstall <name>
```

install.sh 会把 hook snippet upsert 进 `~/.codex/hooks.json`（PreToolUse/PostToolUse 同 Claude 同构）。

## Hooks（Codex）

- Codex 的 hooks 引擎与 Claude Code 同构：`PreToolUse` 可拦截 Bash/apply_patch/MCP，"deny wins"。
- 守卫脚本读 stdin JSON（`tool_name`、`tool_input.command`），可 deny
  （`permissionDecision:"deny"` 或 exit 2 + stderr）或 **allow + 改写**
  （`permissionDecision:"allow"` + `updatedInput.command`，非破坏式重写命令）。
- 例：`wk-xcodebuild` 的 PreToolUse 守卫把裸 `xcodebuild` **静默改写**为 `xcb-run.sh` 调用
  （`allow`+`updatedInput`，无需 agent 重试）；改写失败才回退 deny。`WK_XCB_BYPASS=1` 逃生。

## 现有 Skills

| Plugin | 用途 |
|--------|------|
| `wk-scan-clean-code` | ObjC/Swift 代码清理审计 |
| `wk-ios-component-reuse` | 组件库复用工作流（依赖 ios-components MCP） |
| `wk-symbol-reference-scan` | 全局符号引用扫描 |
| `wk-review` | 本地 git diff 代码审查 |
| `wk-sync-pb` | 同步 proto 并重新生成 ObjC Protobuf |
| `wk-lark-wiki` / `wk-lark-wiki-batch` | iOS 组件 API 文档生成 + 飞书上传 |
| `wk-crash-repro-fix` | iOS Crash 闭环排查 |
| `wk-gh-pr-review-fix` | GitHub PR review 闭环处理 |
| `ios-blocked-words-check` | App Store 审核禁止关键词检查 |
| `wk-xcodebuild` | xcodebuild 智能包装（自动选真机 + 精简输出 + PreToolUse 静默改写） |

## 约定

- 默认中文回答；遵循既有规范，不引入冲突写法。
- 新建代码文件头部署名 `yuxilong`。
- 证据驱动、只读不改用户代码、保守不误删。
- 新增/修改 plugin 须同步 `.claude-plugin/marketplace.json` 与 `.agents/plugins/marketplace.json` 两处登记。
