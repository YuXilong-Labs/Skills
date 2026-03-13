---
description: iOS 组件库复用工作流 — 选型、实现、审查、迁移阶段强制执行"先检索组件再行动"
mode: skill
skill_file: skills/wk-ios-component-reuse/SKILL.md
---

# /wk-ios-component-reuse

iOS 组件库复用工作流，依赖 MCP ios-components server。

## 用法

```
/wk-ios-component-reuse <参数>
```

## 参数格式

以 YAML 或自然语言传入，支持以下字段：

- `mode` — 工作模式：
  - `selection` — 组件选型评估（输出候选矩阵与主备方案）
  - `implementation` — 复用优先实现（默认）
  - `review` — PR 组件复用审查（输出证据链与严重级别）
  - `migration` — 重复实现迁移（输出映射表与分批计划）
- `requirement` — 需求描述、PR 链接、迁移目标等

## 使用示例

### 组件选型

```
/wk-ios-component-reuse mode=selection requirement=做一个带分页列表、空态、下拉刷新的页面
```

### 复用优先实现

```
/wk-ios-component-reuse mode=implementation requirement=实现头像圆角缓存加载，优先复用现有组件
```

### PR 复用审查

```
/wk-ios-component-reuse mode=review requirement=检查这个PR是否有自定义图片下载器
```

### 迁移改造

```
/wk-ios-component-reuse mode=migration requirement=把业务里的URLSession+自定义缓存迁移到基础网络组件
```

### 自然语言

```
/wk-ios-component-reuse 帮我做图片加载的组件选型
/wk-ios-component-reuse 实现上传功能，不要重复造轮子
/wk-ios-component-reuse review 这个 PR 有没有绕过基础组件
/wk-ios-component-reuse 把自定义弹窗替换成基础 UI 组件
```

## 输出

结构化 Markdown 报告，根据模式不同包含：

- **selection** — 候选组件矩阵 + 主/备/不建议方案 + 落地建议
- **implementation** — 检索摘要 + 证据链 + 选型决策表 + 代码实现 + 自检结论
- **review** — 审查结论 + 问题项（含证据链和严重级别）+ 建议动作
- **migration** — 迁移映射表 + 分批改造计划 + 验证/回滚策略

$ARGUMENTS
