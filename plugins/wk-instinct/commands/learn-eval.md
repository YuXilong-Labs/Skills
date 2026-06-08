---
description: 带质量门槛的会话模式提取 — 在保存前自评非显而易见性、可操作性和作用域准确性，过滤低质量 instinct。
mode: skill
skill_file: skills/wk-instinct/SKILL.md
---

# /learn-eval

在 /learn 基础上增加质量自评，只保存真正有价值的模式。

## 用法

```
/learn-eval
/learn-eval <主题关键词>
```

## 与 /learn 的区别

`/learn` 直接提取并保存；`/learn-eval` 保存前先自问：
- 这是非显而易见的吗？
- 未来 Claude 看到这条 instinct 能直接采取行动吗？
- 作用域是否准确（project vs global）？

质量不达标则不保存，并说明原因。

$ARGUMENTS
