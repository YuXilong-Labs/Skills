---
description: 实现前的设计探索 — 需求澄清、方案对比、设计文档输出。在写代码前使用，防止基于未验证假设开工。
mode: skill
skill_file: skills/wk-brainstorm/SKILL.md
---

# /wk-brainstorm

在动手实现之前，通过协作对话把模糊需求转化为清晰设计，再生成可执行的实施计划。

## 用法

```
/wk-brainstorm <需求描述>
```

## 使用示例

```
/wk-brainstorm 我需要一个消息重试机制
/wk-brainstorm 把现有的 IM 消息存储从内存迁移到 SQLite
/wk-brainstorm 新增一个截图发送功能
/wk-brainstorm 重构 RTC 音视频引擎的初始化流程
```

## 输出

1. **设计文档** — `.claude/plans/YYYY-MM-DD_<主题>_设计.md`
2. **实施计划** — `.claude/plans/YYYY-MM-DD_<主题>_计划.md`

## 流程

探索上下文 → 逐个澄清需求 → 提出 2-3 方案 → 分段呈现设计 → 写设计文档 → 自检 → 用户确认 → 制定实施计划

$ARGUMENTS
