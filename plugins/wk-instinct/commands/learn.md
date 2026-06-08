---
description: 从当前 Claude Code 会话提取可复用模式，保存为原子 instinct 文件（置信度从 0.5 开始）。在完成一个任务或发现值得记录的规律后使用。
mode: skill
skill_file: skills/wk-instinct/SKILL.md
---

# /learn

分析当前会话，提取值得复用的模式并保存为 instinct 文件。

## 用法

```
/learn
/learn <主题关键词>
```

## 示例

```
/learn
/learn delegate 内存管理
/learn xcodebuild 构建命令
```

## 触发时机

- 完成一个任务后
- 踩到坑并找到根因后
- 发现项目未记录的隐性约定后
- reviewer 指出一个模式性问题后

$ARGUMENTS
