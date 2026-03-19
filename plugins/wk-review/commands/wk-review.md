---
description: 对本地 git 修改进行代码审查，关注逻辑 bug、crash 风险、内存泄漏、性能问题
mode: skill
skill_file: skills/wk-review/SKILL.md
---

# /wk-review

对本地 git 修改进行资深开发视角的代码审查。

## 用法

```
/wk-review <参数>
```

## 参数格式

以 YAML 或自然语言传入，支持以下字段：

- `scope` — diff 范围（默认 `all`）：
  - `staged` — 仅审查已暂存的修改（`git diff --cached`）
  - `unstaged` — 仅审查未暂存的修改（`git diff`）
  - `all` — 审查所有本地修改（staged + unstaged）
  - `branch` — 审查当前分支相对于主分支的所有修改（`git diff main...HEAD`）
  - `commit:<hash>` — 审查指定 commit 的修改
- `focus` — 可选，聚焦审查领域（逗号分隔）：
  - `logic` — 逻辑 bug
  - `crash` — crash 风险
  - `memory` — 内存问题
  - `performance` — 性能问题
  - `thread` — 线程安全
  - `resource` — 资源管理
  - `bestpractice` — 语言最佳实践
- `severity` — 最低输出级别（默认 `LOW`）：`CRITICAL` / `HIGH` / `MEDIUM` / `LOW`

## 使用示例

### 审查所有本地修改（默认）

```
/wk-review
```

### 仅审查已暂存的修改

```
/wk-review scope=staged
```

### 审查当前分支的所有修改

```
/wk-review scope=branch
```

### 聚焦特定领域

```
/wk-review focus=crash,memory
```

### 审查指定 commit

```
/wk-review scope=commit:abc1234
```

### 自然语言

```
/wk-review 帮我 review 下本地修改，有没有逻辑 bug、crash 问题
/wk-review 看看这个分支的改动有没有内存泄漏
/wk-review 检查暂存区的代码有没有性能问题
```

## 输出

结构化 Markdown 报告，包含：
- 修改概要（文件列表、变更统计）
- 问题列表（按严重程度分级，附文件路径、行号、代码片段、修复建议）
- 影响分析（本次修改对原有逻辑的影响）
- 总结与建议

$ARGUMENTS
