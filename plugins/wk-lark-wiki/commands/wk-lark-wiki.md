---
description: iOS 组件 API 文档生成 + AI 深度润色 + 飞书知识库上传（支持 CocoaPods 组件目录和 mcp-ios-components 双上下文）
mode: skill
skill_file: skills/wk-lark-wiki/SKILL.md
---

# /wk-lark-wiki

iOS 组件 API 文档一站式工作流：增量生成 → 源码验证润色 → 飞书知识库上传（update-or-create）。

自动检测运行上下文：`mcp-ios-components` 项目 或 任意 CocoaPods 组件目录（含 `.podspec`）。

## 用法

```
/wk-lark-wiki <参数>
```

## 参数格式

以 YAML 或自然语言传入，支持以下字段：

- `mode` — 工作流模式（默认 `full`）：
  - `full` — 增量生成 + 差异检测 + 源码验证润色 + 上传（完整流程）
  - `generate` — 仅增量生成 Markdown 文档到 `docs/api/`
  - `polish` — 仅对 `docs/api/` 现有文档执行 AI 深度润色
  - `upload` — 仅上传 `docs/api/polished/`（或 `docs/api/`）到飞书
- `component` — 可选，指定组件名（CocoaPods 上下文自动从 `.podspec` 检测）
- `wiki_node` — 飞书知识库节点 token（upload/full 时必填）
- `pods_dir` — Pods 源码目录路径（仅 mcp-ios-components 上下文需要）
- `ai_fill` — 可选，生成时启用 AI 补全缺注释的 API（默认 `false`）
- `preview` — 可选，预览模式不实际上传（默认 `false`）

## 使用示例

### 在 CocoaPods 组件目录下（自动检测组件名）

```
/wk-lark-wiki
/wk-lark-wiki wiki_node=wikcnXXXX
/wk-lark-wiki mode=generate
```

### 在 mcp-ios-components 项目下

```
/wk-lark-wiki pods_dir=/path/to/Pods wiki_node=wikcnXXXX
/wk-lark-wiki mode=generate pods_dir=/path/to/Pods
/wk-lark-wiki component=BTBaseKit pods_dir=/path/to/Pods wiki_node=wikcnXXXX
```

### 仅润色现有文档

```
/wk-lark-wiki mode=polish
```

### 仅上传到飞书

```
/wk-lark-wiki mode=upload wiki_node=wikcnXXXX
```

### 预览模式（不实际上传）

```
/wk-lark-wiki mode=full preview=true
```

### 自然语言

```
/wk-lark-wiki 帮我更新 BTBaseKit 的文档到飞书，wiki 节点是 wikcnXXXX
/wk-lark-wiki 润色一下 docs/api 里的所有文档
/wk-lark-wiki 生成当前组件的 API 文档
```

## 输出

- **生成报告** — 增量统计（变更/跳过）、组件 API 数量、文件目录架构图
- **润色报告** — 源码验证结果、润色/跳过的文件数、增量变更统计
- **上传报告** — 每个文件的操作类型（更新/新建）、飞书文档链接

## 前置条件

- **上下文二选一**：
  - 在 `mcp-ios-components` 项目目录下（需已构建索引缓存）
  - 在含 `.podspec` 的 CocoaPods 组件目录下（需 MCP ios-components 工具可用）
- **分支限制**：generate / full 模式仅允许在 main/master 分支执行
- 上传需要 lark-cli 已安装并认证：
  ```bash
  npm install -g @larksuite/cli
  lark-cli config init
  lark-cli auth login --recommend
  ```

$ARGUMENTS
