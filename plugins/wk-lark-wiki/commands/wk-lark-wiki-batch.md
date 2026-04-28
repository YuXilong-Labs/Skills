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
- `preview` — 可选，预览模式，不实际上传、不写任何缓存
- `no_polish` — 可选，关闭默认的 Haiku 深度润色
- `provider` — 可选，润色 LLM 提供者：`claude`（默认）或 `codex`
- `force` — 可选，无视源码 / 文档 hash，强制重生成 + 重润色 + 重上传
- `component` — 可选，仅处理指定单个组件（调试用）

## 使用示例

```text
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX preview=true
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX no_polish=true
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX provider=codex
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX force=true
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX component=BTBaseKit
```

## 输出

- 批量处理汇总：成功 / 未变跳过 / 非 main 跳过 / 失败
- 每个组件的 pull / 生成 / 润色 / 上传结果
- 各组件 `<pods_dir>/<component>/.wk-lark-wiki/` 下缓存清单（`raw.md` / `polished.md` / `source-checksums.json` / `raw-checksum.json` / `wiki-mapping.json`）

## 缓存位置

批量产物缓存在每个组件源码目录内：

```
<pods_dir>/<component>/.wk-lark-wiki/
```

由各组件 git 仓库追踪（**不加 `.gitignore`**），用户自行决定是否 commit/push。

## 增量策略

- **源码 hash 未变 + 已有 wiki 映射** → 整组件跳过，不生成/不润色/不上传
- **源码 hash 有变** → 按文件级增量重生成 `raw.md`（未涉及章节保持原样）
- **`raw.md` 未变** → 复用现有 `polished.md`，不调用 Haiku
- **`force=true`** → 跳过所有 hash 检查，全量重做

## 前置条件

- 必须在 `mcp-ios-components` 项目上下文中运行
- `pods_dir` 可访问，且组件目录是 git 仓库
- 上传需要 `lark-cli` 已安装并认证
- 润色默认依赖本地 `claude` CLI（`claude -p --model haiku`）；`provider=codex` 时改用 `codex exec --skip-git-repo-check -m gpt-5-codex`

$ARGUMENTS
