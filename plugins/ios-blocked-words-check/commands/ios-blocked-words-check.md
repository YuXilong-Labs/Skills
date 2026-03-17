---
description: 检查 iOS 源码中的 App Store 审核禁止关键词（赌博、支付、金融等敏感词）
mode: skill
skill_file: skills/ios-blocked-words-check/SKILL.md
---

# /ios-blocked-words-check

检查 iOS 源码中的 App Store 审核禁止关键词。

## 用法

```
/ios-blocked-words-check <参数>
```

## 参数格式

以路径或模式传入：

- `file` — 指定检查的文件路径
- `--staged` — 检查 git staged 的 iOS 源码文件
- `--all [dir]` — 检查目录下所有 iOS 源码文件

## 使用示例

### 检查指定文件

```
/ios-blocked-words-check file=Classes/PB/SendGift.pbobjc.m
```

### 检查 staged 文件

```
/ios-blocked-words-check --staged
```

### 检查整个目录

```
/ios-blocked-words-check --all Classes/
```

### 自然语言

```
/ios-blocked-words-check 帮我检查 SendGift.pbobjc.m 里有没有敏感词
/ios-blocked-words-check 检查所有 protobuf 生成文件的禁止关键词
```

## 输出

结构化报告，包含：
- 违规总数
- 按文件分组的违规明细（行号、关键词、匹配文本、上下文）
- 注释/代码标注

$ARGUMENTS
