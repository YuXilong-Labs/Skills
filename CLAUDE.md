# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Claude Code Skills 仓库 — 面向 iOS/macOS 开发的可安装 Skill 集合。每个 Skill 是一个结构化的 prompt 工作流，通过 `/wk-skill-name` 斜杠命令触发，执行特定的代码分析或工作流任务。

## 架构

仓库采用"独立 Plugin"设计，每个 Skill 是独立 plugin，安装时复制到 `~/.claude/` 和 `~/.codex/` 对应目录：

- `plugins/<name>/` — 独立 plugin 根目录
  - `.claude-plugin/plugin.json` — Plugin 清单
  - `skills/<name>/SKILL.md` — Skill 主定义（frontmatter + 工作流逻辑）
  - `skills/<name>/references/` — Skill 引用的详细参考文档
  - `commands/<name>.md` — 斜杠命令入口（frontmatter 中 `mode: skill` + `skill_file` 指向 SKILL.md）
- `.claude-plugin/marketplace.json` — Plugin Marketplace 清单（指向各 plugin 子目录）

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
   - `skills/wk-<name>/SKILL.md`（含 frontmatter）
   - `skills/wk-<name>/references/`（按需）
   - `commands/wk-<name>.md`（frontmatter 中 `skill_file: skills/wk-<name>/SKILL.md`）
2. **必须**在 `.claude-plugin/marketplace.json` 的 `plugins` 数组中添加条目（否则 Plugin Marketplace 无法发现该 Skill）
3. 更新 `README.md`（Skills 表格、Commands 表格、安装命令列表、使用示例）
4. 设计要符合skill 和 command 的最佳实践

## 现有 Skills / Hooks

| Plugin | 类型 | 用途 | MCP 依赖 |
|--------|------|------|----------|
| `wk-scan-clean-code` | Skill | ObjC/Swift 代码清理审计（字段/死代码/无用文件） | 无 |
| `wk-ios-component-reuse` | Skill | 组件库复用工作流（选型/实现/审查/迁移） | `ios-components` server |
| `wk-symbol-reference-scan` | Skill | 全局符号引用扫描（源码/Headers/二进制） | 无 |
| `wk-review` | Skill | 本地代码修改 Review（bug/crash/内存泄漏/性能） | 无 |
| `wk-sync-pb` | Skill | 同步上游 proto 并重新生成 ObjC Protobuf 代码 | 无 |
| `wk-lark-wiki` | Skill | iOS 组件库 API 文档生成、AI 润色与飞书上传 | 无 |
| `ios-blocked-words-check` | Skill | App Store 审核合规禁止关键词检查 | 无 |
| `ios-blocked-words-hook` | Hook | PostToolUse — Edit/Write iOS 文件后自动触发关键词检查 | 无 |

> **注意**：所有 plugin 必须在 `.claude-plugin/marketplace.json` 中注册，否则 Plugin Marketplace 无法发现。

## Git 约定

- 本仓库提交和推送时**可跳过本地 git pre-commit hook**（使用 `--no-verify`）

## 设计原则

- 证据驱动 — 所有结论必须附带搜索证据链
- 宁可保守 — 不确定的归入"需谨慎确认"，不误删
- 只读不改 — Skill 只输出报告/建议，不自动修改用户代码
- JSON-first 检索 — 多轮小步收敛，避免单次大范围搜索
