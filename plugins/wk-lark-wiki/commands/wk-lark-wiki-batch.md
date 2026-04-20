---
description: 批量生成 iOS 基础组件 API 文档，使用 Haiku 深度润色并上传到飞书知识库（仅 main 分支基础组件）
mode: skill
skill_file: skills/wk-lark-wiki-batch/SKILL.md
---

# /wk-lark-wiki-batch

iOS 基础组件批量文档工作流：按 mcp-ios-components 同规则发现基础组件，只处理本地 main 分支组件，自动拉取远端最新代码，生成 API 文档，默认用本地 Claude Code Haiku 做整文档深度润色，并同步到飞书 Wiki。

## 用法

```text
/wk-lark-wiki-batch <参数>
```

## 参数格式

- `pods_dir` — 必填，Pods 根目录路径
- `wiki_node` — 必填，飞书知识库目标节点 token
- `preview` — 可选，预览模式，不实际上传
- `no_polish` — 可选，关闭默认的 Haiku 深度润色
- `component` — 可选，仅处理指定单个组件（调试用）

## 使用示例

```text
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX preview=true
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX no_polish=true
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX component=BTBaseKit
```

## 输出

- 批量处理汇总：成功 / 跳过 / 失败
- 每个组件的 pull / 生成 / 润色 / 上传结果
- `docs/api/` 与 `docs/api/polished/` 的产物清单

## 前置条件

- 必须在 `mcp-ios-components` 项目上下文中运行
- `pods_dir` 可访问，且组件目录是 git 仓库
- 上传需要 `lark-cli` 已安装并认证
- 润色默认依赖本地 `claude` CLI，可执行 `claude -p --model haiku`

$ARGUMENTS
