---
name: wk-lark-wiki
description: |
  Use when generating, polishing, or uploading iOS component API documentation to Lark Wiki.
  Triggers: in mcp-ios-components project or any CocoaPods component directory (has .podspec).
  Symptoms: need API docs from source code, docs need AI polish, docs need Lark Wiki sync.
---

# WK-Lark-Wiki — iOS 组件 API 文档生成、润色与飞书上传

## 架构概览

```
用户 → /wk-lark-wiki → Step 0: 上下文检测 + 分支校验
                           ↓
                    Step 1: 环境校验
                           ↓
              ┌─ mcp-ios-components ──→ generate_api_docs.py
              └─ CocoaPods 组件 ─────→ MCP tools（get_component_api → get_class_detail → read_source）
                           ↓
                    Step 2: 增量文档生成（源码 hash 比对 + 文件目录架构图）
                           ↓
                    Step 3: 差异检测（文档内容 hash 比对）
                           ↓
                    Step 4: AI 深度润色（读源码验证 + 格式优化）
                           ↓
                    Step 5: 上传飞书（update-or-create）
                           ↓
                    Step 6: Git 追踪（git add docs/api/）
                           ↓
                    Step 7: 汇总报告
```

---

## 前置要求

- **上下文二选一**：
  - 在 `mcp-ios-components` 项目目录下（含 `tools/generate_api_docs.py` + `.cache/index.json`）
  - 在含 `.podspec` 的 CocoaPods 组件目录下（MCP `ios-components` server 已连接且组件已索引）
- **分支限制**：`generate` / `full` 模式仅允许在 `main` 或 `master` 分支执行
- **上传依赖**：`upload` / `full` 模式需要 `lark-cli` 已安装且认证

---

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `mode` | 否 | `full` | 工作流模式：`full` / `generate` / `polish` / `upload` |
| `component` | 否 | 自动检测 | CocoaPods 上下文自动从 `.podspec` 提取；mcp 上下文可手动指定 |
| `wiki_node` | upload/full 时必填 | — | 飞书知识库节点 token（`wikcnXXXX` 或类似格式） |
| `pods_dir` | 否 | — | Pods 源码目录路径（仅 mcp-ios-components 上下文需要） |
| `ai_fill` | 否 | `false` | 生成时启用 AI 补全缺注释的 API |
| `preview` | 否 | `false` | 预览模式，不实际上传 |

---

## 模式路由

| 触发信号 | 对应 mode |
|----------|-----------|
| "生成文档""更新 API 文档""从代码生成" | `generate` |
| "润色文档""优化排版""改善文档质量" | `polish` |
| "上传到飞书""同步到 wiki""发布文档" | `upload` |
| "完整流程""生成并上传""更新文档到飞书"（默认） | `full` |

## 工作流模式

| 模式 | 执行步骤 | 适用场景 |
|------|----------|----------|
| `full`（默认） | 生成 → 差异检测 → 润色 → 上传 → Git 追踪 | 定期更新文档到飞书 |
| `generate` | 仅增量生成 Markdown 到 `docs/api/` → Git 追踪 | 本地文档更新 |
| `polish` | 差异检测 → AI 润色 `docs/api/` → Git 追踪 | 已有文档需优化 |
| `upload` | 仅上传 `docs/api/polished/` 到飞书 | 已润色好只需上传 |

---

## 核心工作流

### Step 0: 上下文检测 + 分支校验

自动检测运行上下文（`mcp-ios-components` 或 `cocoapods-component`）和当前 git 分支。

**校验规则：**
- 上下文检测失败 → 报错并终止
- `generate` / `full` 模式下不在 `main` 或 `master` 分支 → 报错终止
- `polish` / `upload` 模式不限制分支

### Step 1: 环境校验

根据上下文类型校验运行环境：
- **mcp-ios-components** — 确认 `tools/generate_api_docs.py` + `.cache/index.json` 存在
- **CocoaPods 组件** — 确认 `.podspec` 存在 + MCP `search_component` 可用
- **upload/full 模式** — 确认 `lark-cli` 已安装且认证

### Step 2: 增量文档生成（modes: `full`, `generate`）

1. **源码增量检测** — 计算源码 hash 与 `docs/api/.source-checksums.json` 比对，仅处理有变更的文件
2. **文档生成**（分两条路径）：
   - **mcp-ios-components 上下文** → 执行 `python tools/generate_api_docs.py`
   - **CocoaPods 组件上下文** → 使用 MCP 工具链：`get_component_api` → `get_class_detail` → `read_source`
3. **生成文件目录架构图** — 每份文档必须包含 `## 文件目录` 章节（含用途注释）
4. **更新源码 checksums** — 写入 `docs/api/.source-checksums.json`

**关键约束：** 排除 `Example/` 目录、只处理公开 API、仅增量生成、按 [lark-doc-template.md](references/lark-doc-template.md) 模板组装。

> 详细步骤（命令模板、hash 比对逻辑、目录格式要求）见 [step-generate.md](references/step-generate.md)

如果 `mode=generate`，跳过 Step 3-5，直接执行 Step 6-7。

### Step 3: 差异检测（modes: `full`, `polish`）

计算 `docs/api/` 中文档的 MD5 hash，与 `.checksums.json` 比对确定变更文件列表。对变更文件按 `## ` 二级标题做章节级 diff，仅标记有变化的章节需要润色。

> 首次润色（无 `.checksums.json`）→ 全量润色。

### Step 4: AI 深度润色（modes: `full`, `polish`）

Claude Code 直接阅读文档并改写，遵循 [polish-guidelines.md](references/polish-guidelines.md) 中的规则。

**核心要求：**

1. **源码验证润色**（最高优先级）— 润色前必须用 MCP `read_source` 读取源码，验证描述准确性
   - 润色优先级：源码实现 > 注释声明 > 方法名推断
   - `*暂无说明*` 条目必须结合源码生成准确描述
2. **首次全量润色** — 读取文档 → 按 polish-guidelines 改写 → 写入 `docs/api/polished/`
3. **增量润色** — 仅对变更章节执行源码验证 + 格式润色，未变更章节保持原样
4. **大文档并行** — API 数量 > 100 时按章节分组派发 Agent 子进程并行润色
5. **更新 checksums** — 写入 `docs/api/.checksums.json`

### Step 5: 上传飞书 — update-or-create（modes: `full`, `upload`）

上传润色后的文档（优先 `docs/api/polished/`，若不存在则用 `docs/api/`）。按 update-or-create 逻辑：先查 `.wiki-mapping.json` 已有映射 → update；无映射则搜索飞书 → 匹配则 update，不匹配则 create。

> 详细上传流程（lark-cli 命令、映射文件格式、预览模式）见 [step-upload.md](references/step-upload.md)

### Step 6: Git 追踪（所有模式）

```bash
git add docs/api/
git add docs/api/.checksums.json docs/api/.source-checksums.json docs/api/.wiki-mapping.json 2>/dev/null
git status docs/api/
```

**通知用户：** 文档已 stage 到暂存区，但未自动 commit。

### Step 7: 汇总报告

输出结构化执行报告：模式、上下文、处理概况（生成/润色/上传数量）、文件明细表、问题与建议。

---

## 安全规则

> ⚠️ 以下规则优先级最高，不可违反。

1. **只读源码** — Skill 只读取源码和索引生成文档，不修改任何源文件
2. **润色输出隔离** — 润色结果写入 `docs/api/polished/`，不覆盖原始生成文档
3. **分支保护** — `generate` / `full` 模式仅在 `main` / `master` 分支执行，其他分支报错终止
4. **更新优先** — 上传飞书时先查已有文档再决定 update 或 create，避免重复创建
5. **预览模式** — `preview=true` 时仅展示操作计划，不实际执行上传/更新
6. **输出重定向** — 所有可能产生大量输出的命令重定向到临时文件，对话中只展示末尾摘要
7. **源码润色准确性** — 润色描述必须与源码实现一致，不臆测功能；不确定时标注"需确认"
8. **Example 排除** — CocoaPods 组件上下文中始终排除 `Example/` 目录

---

## 质量门槛

- 文档存在 `*暂无说明*` 残留但未尝试源码验证 → **不合格**
- 文件目录架构图缺失或无注释 → **不合格**
- 上传时未检查已有文档直接 create（导致重复文档） → **不合格**
- 非 main/master 分支执行 generate/full 模式 → **不合格**
- 源码验证发现描述不准确但未修正 → **不合格**

---

## 文件目录约定

```
docs/api/                         # 原始生成文档
  ├── BTBaseKit.md
  ├── index.md
  ├── .checksums.json             # 文档内容 hash（润色增量用）
  ├── .source-checksums.json      # 源码 hash（生成增量用）
  └── .wiki-mapping.json          # 组件 → 飞书 doc_id 映射
docs/api/polished/                # AI 润色后文档（上传用）
  ├── BTBaseKit.md
  └── index.md
```
