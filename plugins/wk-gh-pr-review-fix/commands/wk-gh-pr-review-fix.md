---
description: 拉取当前 GitHub PR 的 unresolved review threads，修复代码并在验证后推送、回复和 resolve
mode: skill
skill_file: skills/wk-gh-pr-review-fix/SKILL.md
---

# /wk-gh-pr-review-fix

处理当前分支 PR 的 review 闭环。

## 用法

```bash
/wk-gh-pr-review-fix <参数>
```

## 参数格式

支持自然语言或以下字段：

- `repo` — 可选，仓库名，格式 `owner/name`
- `pr` — 可选，PR 编号或 URL，默认取当前分支 PR
- `mode` — 可选，默认 `fix-all`
  - `inspect` — 只拉取并汇总 review/check 状态，不改代码
  - `fix-all` — 处理所有 unresolved actionable threads
  - `reply-only` — 不改代码，只对已完成修复的线程回复并 resolve

## 示例

```bash
/wk-gh-pr-review-fix
/wk-gh-pr-review-fix mode=inspect
/wk-gh-pr-review-fix pr=14
/wk-gh-pr-review-fix repo=YuXilong-Labs/LLVM-Hikari pr=14
```

## 说明

- 默认只处理 unresolved actionable review threads
- 若当前没有新的 actionable review，会明确报告并停止，不会制造空提交
- 修复后会按线程回复并 resolve，而不是发顶层 PR comment

$ARGUMENTS
