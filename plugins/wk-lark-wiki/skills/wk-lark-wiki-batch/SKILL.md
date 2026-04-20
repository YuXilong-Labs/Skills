---
name: wk-lark-wiki-batch
description: |
  Use when batch-generating, Haiku-polishing, or uploading multiple iOS base component API docs to Lark Wiki.
  Triggers: in mcp-ios-components project with pods_dir, need main-branch base components only, need batch wiki sync.
  Symptoms: need all base components docs at once, want default Haiku whole-document polish, need branch auto-pull + update-or-create upload.
---

# WK-Lark-Wiki-Batch — main 分支基础组件批量文档生成、Haiku 润色与飞书上传

## 架构概览

```
用户 → /wk-lark-wiki-batch → Step 0: 上下文 + 参数校验
                                   ↓
                            Step 1: 发现基础组件（与 MCP 启动同规则）
                                   ↓
                            Step 2: 分支检测 + main 分支 git pull --ff-only
                                   ↓
                            Step 3: 逐组件生成 Markdown → docs/api/
                                   ↓
                            Step 4: 默认 Haiku 整文档润色 → docs/api/polished/
                                   ↓
                            Step 5: update-or-create 上传飞书
                                   ↓
                            Step 6: git add docs/api/（本地追踪）
                                   ↓
                            Step 7: 汇总报告
```

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `pods_dir` | 是 | — | Pods 源码根目录 |
| `wiki_node` | 是 | — | 飞书目标 wiki 节点 token（`wikcnXXXX`） |
| `preview` | 否 | `false` | 预览模式：不执行 lark-cli，不写 polished/ |
| `no_polish` | 否 | `false` | 跳过 Step 4（默认启用 Haiku 深度润色） |
| `component` | 否 | — | 仅处理指定组件，调试用 |

## 前置要求

- 当前目录应为 `mcp-ios-components` 项目（含 `tools/generate_api_docs.py` 与 `mcp_app/`）
- `$PYTHON311` 可用（默认 `/opt/homebrew/opt/python@3.11/bin/python3.11` 或 `PYTHONPATH=. python3`）
- 上传需 `lark-cli` 已认证
- 润色需本地 `claude` CLI（Claude Code）可用并登录

---

## Step 0: 上下文检测 + 参数校验

- 确认当前目录存在 `mcp_app/bootstrap.py` 与 `tools/generate_api_docs.py`；否则终止。
- 校验 `pods_dir` 目录存在；不存在终止。
- `preview=false` 且未提供 `wiki_node` → 终止。
- 解析布尔型参数 `preview` / `no_polish`，默认 `false`。

## Step 1: 发现基础组件

运行（输出为 JSON 组件名列表）：

```bash
PYTHONPATH=. python3 - <<'PY'
from mcp_app import bootstrap
import json, sys
pods_dir = "<pods_dir>"
print(json.dumps(sorted(bootstrap.discover_components(pods_dir)), ensure_ascii=False))
PY
```

如提供了 `component`，从结果中过滤出唯一名；若不在发现结果中 → 记 failed 跳过后续步骤。

## Step 2: 分支检测 + main 分支 pull

对每个候选组件目录执行：

```bash
PYTHONPATH=. python3 - <<'PY'
from mcp_app.integrations.git_client import get_git_repo_branch, git_pull_repo
import json, sys
repo = "<pods_dir>/<component>"
branch = get_git_repo_branch(repo)
if branch != "main":
    print(json.dumps({"skipped": True, "branch": branch}))
    sys.exit(0)
print(json.dumps({"branch": branch, "pull": git_pull_repo(repo)}))
PY
```

分支非 `main` → 进入 `skipped` 列表，`reason=non-main branch: <branch>`；不再做 Step 3-5。
`pull.error` 不为空 → 进入 `failed` 列表，`reason=pull failed: ...`。

## Step 3: 生成 Markdown

- 复用 mcp-ios-components 已有的单组件生成能力：

```bash
PYTHONPATH=. python3 tools/generate_api_docs.py \
  --pods-dir <pods_dir> --component <component> \
  --output-dir docs/api 2>&1 | tee /tmp/wk-lark-wiki-batch-gen.log | tail -30
```

- 生成后确认 `docs/api/<component>-*.md` 存在，否则视为失败。

> 生成器规则、文件目录格式等详见 [../wk-lark-wiki/references/step-generate.md](../wk-lark-wiki/references/step-generate.md)

## Step 4: Haiku 整文档润色（默认）

`no_polish=true` 时跳过本步骤。

对每个生成的 Markdown 文件执行：

```bash
mkdir -p docs/api/polished
INPUT="docs/api/<generated-file>.md"
OUTPUT="docs/api/polished/<generated-file>.md"
claude -p --model haiku \
  "你是 iOS API 文档润色器。严格遵循 polish-guidelines 的结构模板、描述规则与飞书 Markdown 最佳实践。输入是一整份 Markdown 文档，直接输出润色后的完整 Markdown，不要解释、不要多余文本。" \
  < "$INPUT" > "$OUTPUT"
```

- 如果本地 `claude` CLI 不识别 `--model haiku`，改用：`--model claude-haiku-4-5`
- 润色失败（非零退出或空文件）→ 记录 warning，回退使用原始 `docs/api/<file>.md` 走 Step 5，不中断整批。
- `preview=true` 时不写 `polished/`，仅打印"将使用 Haiku 润色 `<file>`"。

> 润色规则详见 [../wk-lark-wiki/references/polish-guidelines.md](../wk-lark-wiki/references/polish-guidelines.md)

## Step 5: update-or-create 上传飞书

优先取 `docs/api/polished/<file>.md`；不存在（`no_polish=true` 或润色失败）时退回 `docs/api/<file>.md`。

对每个组件按 update-or-create 逻辑上传到同一 `wiki_node`：

1. 从 `docs/api/.wiki-mapping.json` 查 `<component>.doc_id`
2. 有 `doc_id`：`lark-cli docs +update --doc <doc_id> --mode overwrite --markdown-file <file> --as user`，失败则清理映射继续 step 3
3. 无映射：`lark-cli docs +search --query "<component>" --as user`；匹配则 update，否则 `lark-cli docs +create --title "<component>" --markdown-file <file> --wiki-node <wiki_node> --as user`
4. 更新 `.wiki-mapping.json`

`preview=true` 时只打印每个组件的计划动作（create / update + doc_id + title），不执行 lark-cli。

> 上传规则与 .wiki-mapping.json 结构详见 [../wk-lark-wiki/references/step-upload.md](../wk-lark-wiki/references/step-upload.md)

## Step 6: Git 追踪

```bash
git add docs/api/ 2>/dev/null || true
git status docs/api/ | head -20
```

通知用户：文档已 stage 到暂存区，但未自动 commit。

## Step 7: 汇总报告

输出结构化：

```
===== wk-lark-wiki-batch 汇总 =====
成功 N  跳过 M  失败 K  (润色成功 P  回退原文 F)

[成功]
  - <component>  →  <doc_url>
...

[跳过（非 main 分支）]
  - <component>  原因: non-main branch: <branch>
...

[失败]
  - <component>  原因: <reason>
...
```

---

## 安全规则

> 以下规则优先级最高，不可违反。

1. **分支保护** — 只处理本地分支 `== main`，其余进入 skipped，不做生成/上传
2. **自动 pull 用 ff-only** — 避免任何 merge commit，冲突即失败
3. **预览不触达飞书** — `preview=true` 下禁止调用任何写操作 lark-cli 命令
4. **默认润色可回退** — Haiku 润色失败不中断整批，改用原始文档继续上传
5. **失败隔离** — 单组件任一步失败不影响其它组件
6. **update-or-create 不重复** — 上传必须先查后建，避免重复 wiki 文档
7. **Example 排除** — 文档生成时排除 `Example/`，沿用单组件 skill 约束

## 与 /wk-lark-wiki 的区别

| 维度 | `/wk-lark-wiki` | `/wk-lark-wiki-batch` |
|------|-----------------|-----------------------|
| 范围 | 单组件（对话式） | 全部 main 分支基础组件 |
| 组件来源 | 手动指定或自动从 .podspec | `mcp_app.bootstrap.discover_components` |
| 分支策略 | 校验当前分支 | 逐组件 pull + 筛 main |
| 润色 | 文档级（默认开启） | 文档级 Haiku（默认开启，可关） |
| 上传 | 单文档 update-or-create | 同一 wiki_node 批量 update-or-create |
