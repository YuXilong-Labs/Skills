---
description: Skill 生成工具 — 分析 git 历史提取编码模式生成 SKILL.md 草稿，或把一组高置信度 instinct 演化为正式 Skill。
mode: skill
skill_file: skills/wk-skill-create/SKILL.md
---

# /wk-skill-create

生成新 Skill 的草稿文件，支持两种模式：分析 git 历史或从 instinct 演化。

## 用法

```
/wk-skill-create <主题>
/wk-skill-create mode=instinct <主题>
/wk-skill-create commits=100 <主题>
```

## 参数

- `mode` — `git`（默认，分析提交历史）/ `instinct`（从 instinct 演化）
- `commits` — 分析最近 N 条提交（默认 200）
- `topic` — 要提取的主题

## 示例

```
/wk-skill-create 网络请求错误处理
/wk-skill-create mode=instinct delegate 内存管理
/wk-skill-create commits=50 CoreData 数据库操作
```

## 输出

生成标准 plugin 目录结构到 `plugins/wk-<name>/`，含：
- `SKILL.md` 草稿（需人工审核补充）
- `commands/wk-<name>.md`
- 两个 `plugin.json`

$ARGUMENTS
