# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Claude Code Skills 仓库 — 面向 iOS/macOS 开发的可安装 Skill 集合。每个 Skill 是一个结构化的 prompt 工作流，通过 `/wk-skill-name` 斜杠命令触发，执行特定的代码分析或工作流任务。

## 架构

仓库采用"独立 Plugin"设计，每个 Skill 是独立 plugin，安装时复制到 `~/.claude/` 和 `~/.codex/` 对应目录：

- `plugins/<name>/` — 独立 plugin 根目录
  - `.claude-plugin/plugin.json` — Claude Code Plugin 清单
  - `.codex-plugin/plugin.json` — Codex Plugin 清单（skill 类 plugin 必备，原生 Codex marketplace 用）
  - `skills/<name>/SKILL.md` — Skill 主定义（frontmatter + 工作流逻辑）
  - `skills/<name>/references/` — Skill 引用的详细参考文档
  - `commands/<name>.md` — 斜杠命令入口（frontmatter 中 `mode: skill` + `skill_file` 指向 SKILL.md）
  - `hooks/hooks.json` — （含 hook 的 plugin）原生 plugin hook，路径用 `${CLAUDE_PLUGIN_ROOT}` / `${PLUGIN_ROOT}`
- `.claude-plugin/marketplace.json` — Claude Plugin Marketplace 清单（指向各 plugin 子目录）
- `.agents/plugins/marketplace.json` — Codex Plugin Marketplace 清单（`source.path` 指向 `./plugins/<name>`）

### 双端发布（Claude Code + Codex）

- **install.sh**（通用回退）：双目标复制到 `~/.claude` 与 `~/.codex`，并把 hook snippet
  upsert 进 `~/.claude/settings.json` 与 `~/.codex/hooks.json`。
- **原生 marketplace**：Claude 用 `/plugin install`（读 `.claude-plugin/`）；
  Codex 用 `codex plugin marketplace add`（读 `.agents/plugins/marketplace.json` + 各 `.codex-plugin/plugin.json`）。
- Codex hooks 与 Claude 同构（`PreToolUse`/`PostToolUse`、`tool_input.command`、`permissionDecision`），
  hook 守卫脚本两端共用。
- **不可原生化的 plugin**：`ios-dev-rules`（规则类，Codex plugin 无 rules 字段）、
  `ios-blocked-words-hook`（hook 跨 plugin 依赖脚本）——仅走 install.sh，不编入 `.agents/plugins/marketplace.json`。

### Skill 文件结构约定

每个 Skill 的 `SKILL.md` 必须包含：
1. YAML frontmatter（`name`、`description`）
2. 输入参数表
3. 模式/工作流说明
4. 引用 `references/` 中的详细文档

每个 Command 的 `commands/<name>.md` 必须包含：
1. YAML frontmatter（`description`、`mode: skill`、`skill_file` 指向对应 SKILL.md）
2. 用法说明和参数格式
3. 使用示例

## 常用命令

```bash
# 安装所有 Skills 到 ~/.claude/ 和 ~/.codex/
./install.sh

# 安装单个 Skill
./install.sh wk-scan-clean-code

# 列出可用 Skills
./install.sh --list

# 卸载（同时清理双目标）
./install.sh --uninstall wk-scan-clean-code

# 远程一键安装
curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash
```

## 新增 Skill 流程

1. 创建 `plugins/wk-<name>/` 目录结构：
   - `.claude-plugin/plugin.json`
   - `.codex-plugin/plugin.json`（skill 类 plugin 必备，可从 `.claude-plugin/plugin.json` 派生 + 补 `skills`/`interface`）
   - `skills/wk-<name>/SKILL.md`（含 frontmatter）
   - `skills/wk-<name>/references/`（按需）
   - `commands/wk-<name>.md`（frontmatter 中 `skill_file: skills/wk-<name>/SKILL.md`）
2. **必须**在 `.claude-plugin/marketplace.json` 的 `plugins` 数组中添加条目（否则 Claude Plugin Marketplace 无法发现该 Skill）
3. **必须**在 `.agents/plugins/marketplace.json` 的 `plugins` 数组中添加条目（否则 Codex Marketplace 无法发现；纯 rules/跨 plugin 依赖的 hook 除外）
4. 更新 `README.md`（Skills 表格、Commands 表格、安装命令列表、Codex 安装说明、使用示例）
5. 设计要符合skill 和 command 的最佳实践

## 现有 Skills / Hooks

| Plugin | 类型 | 用途 | MCP 依赖 |
|--------|------|------|----------|
| `wk-scan-clean-code` | Skill | ObjC/Swift 代码清理审计（字段/死代码/无用文件） | 无 |
| `wk-ios-component-reuse` | Skill | 组件库复用工作流（选型/实现/审查/迁移） | `ios-components` server |
| `wk-symbol-reference-scan` | Skill | 全局符号引用扫描（源码/Headers/二进制） | 无 |
| `wk-review` | Skill | 本地代码修改 Review（bug/crash/内存泄漏/性能） | 无 |
| `wk-sync-pb` | Skill | 同步上游 proto 并重新生成 ObjC Protobuf 代码 | 无 |
| `wk-lark-wiki` | Skill | iOS 组件库 API 文档生成、AI 润色与飞书上传 | 无 |
| `wk-crash-repro-fix` | Skill | iOS Crash 闭环排查（根因→复现→修复→回归验证） | 无 |
| `wk-gh-pr-review-fix` | Skill | GitHub PR review 闭环处理（拉 review→修复→验证→推送→回复并 resolve） | 无 |
| `wk-xcodebuild` | Skill + Hook | xcodebuild / swift(SwiftPM) 智能包装 — 自动选 USB 真机目标（无则回退 Mac），rtk 风格精简 build/test 输出节省 token；PreToolUse 把裸 xcodebuild 与 swift build/test 静默改写为包装器（allow+updatedInput） | 无 |
| `ios-blocked-words-check` | Skill | App Store 审核合规禁止关键词检查 | 无 |
| `ios-blocked-words-hook` | Hook | PostToolUse — Edit/Write iOS 文件后自动触发关键词检查 | 无 |
| `ios-dev-rules` | Rules | iOS 三语言编码规范（ObjC/Swift/Ruby），安装到 ~/.claude/rules/ | 无 |

> **注意**：所有 plugin 必须在 `.claude-plugin/marketplace.json` 中注册，否则 Plugin Marketplace 无法发现。

## Git 约定

- 本仓库提交和推送时**可跳过本地 git pre-commit hook**（使用 `--no-verify`）

## Rules 修改约定

修改 `plugins/ios-dev-rules/rules/**` 下任何文件时，**必须**在同一 commit 中同步 bump 版本号：

1. 运行 `./scripts/bump-rules-version.sh <new-version>` 一次性更新两处：
   - `plugins/ios-dev-rules/.claude-plugin/plugin.json`（单一真相源）
   - `.claude-plugin/marketplace.json`（ios-dev-rules 条目）
2. 提交前运行 `./scripts/bump-rules-version.sh --check` 自检，确保两处一致
3. **不允许**只改一处，两处必须同步

版本号语义：
- `patch`（x.x.N）：修改规则文案、措辞、示例
- `minor`（x.N.0）：新增或删除规则文件
- `major`（N.0.0）：破坏性改动（如重命名语言目录、删除整个语言规则集）

## 设计原则

- 证据驱动 — 所有结论必须附带搜索证据链
- 宁可保守 — 不确定的归入"需谨慎确认"，不误删
- 只读不改 — Skill 只输出报告/建议，不自动修改用户代码
- JSON-first 检索 — 多轮小步收敛，避免单次大范围搜索
