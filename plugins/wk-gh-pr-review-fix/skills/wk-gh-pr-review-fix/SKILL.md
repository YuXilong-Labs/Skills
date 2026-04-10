---
name: wk-gh-pr-review-fix
description: Use when working on a GitHub pull request and the task is to inspect unresolved review threads, act on actionable feedback, and close the loop by verifying, pushing, replying, and resolving the threads.
---

# WK-GH-PR-Review-Fix

GitHub PR review 闭环处理 Skill。目标不是“读评论”，而是把 unresolved actionable review 真正收口到代码、验证和线程状态。

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `repo` | 否 | 当前仓库远端 | GitHub 仓库，格式 `owner/name` |
| `pr` | 否 | 当前分支 PR | PR 编号或 URL |
| `mode` | 否 | `fix-all` | `inspect` / `fix-all` / `reply-only` |

## 工作模式

- `inspect`
  只拉取最新 review/check 状态，输出 unresolved actionable threads，不改代码。
- `fix-all`
  默认模式。处理所有 unresolved actionable threads，完成修复、本地验证、推送、回复与 resolve。
- `reply-only`
  适合代码已在本地或远端完成，只做线程回复和 resolve。

## 核心工作流

1. 解析当前分支对应的 PR；如果用户给了 `repo` / `pr`，优先使用显式输入。
2. 用 thread-aware 方式获取 review 状态，不只看顶层 comment。
3. 只筛 unresolved actionable threads；如果没有，明确报告并停止。
4. 对每条反馈做技术核实，确认是否真的需要改代码。
5. 需要改代码时先补最小失败测试，再做最小修复。
6. 按仓库的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` 要求做本地验证。
7. 只有在 fresh verification 通过后才允许提交、推送。
8. 在线程里回复修复说明和验证证据，然后 resolve thread。
9. 回拉最终状态，确认没有遗漏的 unresolved 线程。

## 关键规则

- **必须**使用 thread-aware review 数据。顶层 PR review summary 不能代替 review thread 状态。
- **必须**先判断 comment 是否 actionable，再决定是否改代码。
- **必须**遵守 `receiving-code-review`：先核实，再实现，不做表演式认同。
- **必须**遵守 `test-driven-development`：要改代码时先写失败测试。
- **必须**遵守 `verification-before-completion`：没有 fresh verification，不得声称已修复。
- 没有新的 unresolved actionable thread 时，**不得**制造空提交、空推送或冗余回复。
- 回复 review 时必须在线程内回复，不能用顶层 PR comment 代替。

## 详细步骤

### Step 1：解析 PR

- 优先使用当前分支 PR
- 用户提供 `pr` 或 `repo` 时按显式输入覆盖

### Step 2：获取 thread-aware review 状态

使用 `gh-address-comments` 的脚本或 GraphQL 拉取：
- `reviewThreads`
- `isResolved`
- `isOutdated`
- inline comment 的 `databaseId`

命令见：
[review-thread-commands.md](references/review-thread-commands.md)

### Step 3：筛 actionable threads

保留：
- unresolved inline review thread
- 明确要求改代码、修 bug、补契约或补验证的评论

过滤：
- 已 resolved
- 仅信息提示
- bot summary 但没有对应 unresolved thread

### Step 4：核实评论

逐条检查：
- reviewer 说的问题是否真的成立
- 当前实现是否有 repo-specific 原因
- 是否需要代码修复，还是只需技术解释

### Step 5：先写失败测试

凡是需要改代码：
- 先补最小测试
- 先看它失败
- 再做最小改动修复

### Step 6：本地验证

验证顺序：
1. 针对 review 问题的最小测试
2. 仓库要求的构建/脚本/增量验证
3. 受影响范围的 smoke 或 quick suite

验证清单见：
[local-verification-checklist.md](references/local-verification-checklist.md)

### Step 7：提交与推送

只有发生真实代码变化时才允许：
- `git add` 目标文件
- 跑仓库要求的 staged 检查
- 提交
- 推送

### Step 8：在线程中回复并 resolve

回复内容至少包含：
- 已修复
- 对应提交 SHA
- 具体改动点
- 本地验证命令与结果

然后 resolve 对应 thread。

## 常见错误

- 只看 `gh pr view` 的顶层 review summary
- 把所有评论都当成 actionable
- 没有 fresh verification 就去回复 review
- 代码没变却硬做一次 commit / push
- 用顶层 comment 回复 inline review
- resolve thread 后不回拉最终状态

## 参考资料

- [review-thread-commands.md](references/review-thread-commands.md)
- [local-verification-checklist.md](references/local-verification-checklist.md)
