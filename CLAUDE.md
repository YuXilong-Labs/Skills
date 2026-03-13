# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Claude Code Skills 仓库 — 面向 iOS/macOS 开发的可安装 Skill 集合。每个 Skill 是一个结构化的 prompt 工作流，通过 `/skill-name` 斜杠命令触发，执行特定的代码分析或工作流任务。

## 架构

仓库采用"双目录映射"设计，安装时直接复制到 `~/.claude/` 对应目录：

- `skills/<name>/SKILL.md` — Skill 主定义（frontmatter + 工作流逻辑），安装到 `~/.claude/skills/<name>/`
- `skills/<name>/references/` — Skill 引用的详细参考文档（搜索策略、输出格式等）
- `commands/<name>.md` — 斜杠命令入口（frontmatter 中 `mode: skill` + `skill_file` 指向 SKILL.md），安装到 `~/.claude/commands/`
- `.claude-plugin/` — Plugin Marketplace 清单（`plugin.json` + `marketplace.json`）

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
# 安装所有 Skills 到 ~/.claude/
./install.sh

# 安装单个 Skill
./install.sh scan-clean-code

# 列出可用 Skills
./install.sh --list

# 卸载
./install.sh --uninstall scan-clean-code
```

## 新增 Skill 流程

1. 创建 `skills/<name>/SKILL.md`（含 frontmatter）
2. 按需添加 `skills/<name>/references/*.md`
3. 创建 `commands/<name>.md`（frontmatter 中 `skill_file: skills/<name>/SKILL.md`）
4. 在 `.claude-plugin/marketplace.json` 的 `plugins` 数组中添加条目
5. 更新 `README.md`

## 现有 Skills

| Skill | 用途 | MCP 依赖 |
|-------|------|----------|
| `scan-clean-code` | ObjC/Swift 代码清理审计（字段/死代码/无用文件） | 无 |
| `ios-component-reuse` | 组件库复用工作流（选型/实现/审查/迁移） | `ios-components` server |
| `symbol-reference-scan` | 全局符号引用扫描（源码/Headers/二进制） | 无 |

## 设计原则

- 证据驱动 — 所有结论必须附带搜索证据链
- 宁可保守 — 不确定的归入"需谨慎确认"，不误删
- 只读不改 — Skill 只输出报告/建议，不自动修改用户代码
- JSON-first 检索 — 多轮小步收敛，避免单次大范围搜索
