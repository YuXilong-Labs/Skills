---
name: wk-lark-wiki-batch
description: |
  Use when batch-generating, Haiku-polishing, or uploading multiple iOS base component API docs to Lark Wiki.
  Triggers: in mcp-ios-components project with pods_dir, need main-branch base components only, need batch wiki sync.
  Symptoms: need all base components docs at once, want default Haiku whole-document polish, need branch auto-pull + update-or-create upload, need hash-based incremental skip.
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
                            Step 3: 源码 hash 对比 — 完全未变 → 跳过整组件
                                   ↓
                            Step 4: 文件级增量生成 Markdown → <component>/.wk-lark-wiki/raw.md
                                   ↓
                            Step 5: Haiku 整文档润色（raw hash 未变复用缓存） → <component>/.wk-lark-wiki/polished.md
                                   ↓
                            Step 6: update-or-create 上传飞书
                                   ↓
                            Step 7: Git 追踪（组件内 stage）
                                   ↓
                            Step 8: 汇总报告
```

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `pods_dir` | 是 | — | Pods 源码根目录 |
| `wiki_node` | 是 | — | 飞书目标 wiki 节点 token（`wikcnXXXX`） |
| `preview` | 否 | `false` | 预览模式：不执行 lark-cli，不写入任何 `.wk-lark-wiki/` 文件 |
| `no_polish` | 否 | `false` | 跳过 Step 5（默认启用 Haiku 深度润色） |
| `force` | 否 | `false` | 无视所有缓存 hash，强制重生成 + 重润色 + 重上传 |
| `component` | 否 | — | 仅处理指定组件，调试用 |

## 前置要求

- 当前目录为 `mcp-ios-components` 项目（含 `tools/generate_api_docs.py` 与 `mcp_app/`）
- 上传需 `lark-cli` 已认证
- 润色需本地 `claude` CLI 可用并登录

---

## 组件内部缓存约定（核心）

**所有批量产物缓存在每个组件源码目录的 `.wk-lark-wiki/`**，由各组件自己的 git 仓库追踪（**不加 `.gitignore`**，允许入库）。

```
<pods_dir>/<component>/
  └── .wk-lark-wiki/
      ├── raw.md                    # 生成的原始 API Markdown（润色输入 / 上传回退源）
      ├── polished.md               # Haiku 润色后的最终稿（优先上传源）
      ├── source-checksums.json     # 源码文件级 hash 表（决定是否重生成）
      ├── raw-checksum.json         # raw.md 内容 hash（决定是否重润色）
      └── wiki-mapping.json         # 该组件→飞书文档的 doc_id / doc_url 映射
```

**为什么入组件仓库：**
- `source-checksums.json` 必须与源码 commit 绑定，才能判定"相对某次源码状态是否已经生成过文档"
- `polished.md` 是最终上传稿，需可追溯审查
- `wiki-mapping.json` 是组件→wiki 文档的绑定，丢失会触发重复 create

---

## Step 0: 上下文检测 + 参数校验

- 确认当前目录含 `mcp_app/bootstrap.py` 与 `tools/generate_api_docs.py`；否则终止。
- 校验 `pods_dir` 目录存在；不存在终止。
- `preview=false` 且未提供 `wiki_node` → 终止。
- 解析布尔参数 `preview` / `no_polish` / `force`，默认 `false`。

## Step 1: 发现基础组件

```bash
PYTHONPATH=. python3 - <<'PY'
from mcp_app import bootstrap
import json
pods_dir = "<pods_dir>"
print(json.dumps(sorted(bootstrap.discover_components(pods_dir)), ensure_ascii=False))
PY
```

如提供了 `component`，从结果中过滤出唯一名；不在发现结果中 → 记 failed 跳过后续。

## Step 2: 分支检测 + main 分支 pull

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

- 分支 ≠ `main` → `skipped`，reason=`non-main branch: <branch>`，跳过后续。
- `pull.error` 不空 → `failed`，reason=`pull failed: ...`，跳过后续。

## Step 3: 源码 hash 对比（组件级跳过）

对每个 main 分支组件：

1. 遍历 `<pods_dir>/<component>/**/*.{h,m,mm,swift}`（排除 `Example/` / `Pods/` / `.git/` / `DerivedData/`），计算文件级 MD5，聚合为 `{rel_path: md5}` 存为 `cur_checksums`。
2. 读取 `<pods_dir>/<component>/.wk-lark-wiki/source-checksums.json`（缺失视为 `{}`）作为 `cached_checksums`。
3. 对比：
   - `force=true` → 继续下一步（视为全部变更）
   - `cur_checksums == cached_checksums` 且 `raw.md` / `polished.md` / `wiki-mapping.json.doc_id` 齐全 → 标记 `unchanged=True`，直接跳到 Step 6（且 Step 6 默认 `skip upload`）
   - 否则 → `changed_files = 差集（新增 + 修改 + 删除）`，继续 Step 4
4. `cur_checksums` 仅在 Step 4 生成成功后再落盘。

## Step 4: 文件级增量生成（原始 Markdown）

生成命令（本地临时输出）：

```bash
PYTHONPATH=. python3 tools/generate_api_docs.py \
  --pods-dir <pods_dir> --component <component> \
  --output-dir /tmp/wk-lark-wiki-batch 2>&1 | tee /tmp/wk-lark-wiki-batch-gen.log | tail -30
```

合并策略：

- **首次 / `force=true` / 无现有 raw.md** → 整体覆盖写入 `<component>/.wk-lark-wiki/raw.md`。
- **增量**：读取现有 `raw.md`，按 `## ` 二级标题切分为章节；对 `changed_files` 涉及的类/协议章节用新生成内容替换，未涉及的章节原样保留，合并后写回 `raw.md`。章节到文件的映射依据 `comp.apis[*].file` 与 `host_class`。

其它约束：
- 生成失败 → `failed`，**不**更新任何缓存文件（保持原子）。
- `raw.md` 写入成功后，再把 Step 3 的 `cur_checksums` 写入 `source-checksums.json`（同进同退）。
- `preview=true` 时不写任何 `.wk-lark-wiki/` 文件，仅打印"将写入 `<component>/.wk-lark-wiki/raw.md`"。

> 生成器命令行规则见 [../wk-lark-wiki/references/step-generate.md](../wk-lark-wiki/references/step-generate.md)

## Step 5: Haiku 整文档润色（默认）

`no_polish=true` 时跳过。

1. 计算 `sha256(raw.md)` 存为 `raw_sha`。
2. 读取 `<component>/.wk-lark-wiki/raw-checksum.json`（缺失视为空）。
3. 分支：
   - `force=true` → 强制调用 Haiku
   - `raw_sha == cached.raw_sha` 且 `polished.md` 存在 → 复用现有 `polished.md`，`polish_status=cached`，不调用 Haiku
   - 否则 → 调用 Haiku：

```bash
INPUT="<pods_dir>/<component>/.wk-lark-wiki/raw.md"
OUTPUT="<pods_dir>/<component>/.wk-lark-wiki/polished.md"
claude -p --model haiku \
  "你是 iOS API 文档润色器。严格遵循 polish-guidelines 的结构模板、描述规则与飞书 Markdown 最佳实践。输入是一整份 Markdown 文档，直接输出润色后的完整 Markdown，不要解释、不要多余文本。" \
  < "$INPUT" > "$OUTPUT"
```

- `--model haiku` 不识别时改用 `--model claude-haiku-4-5`
- 润色失败（非零退出 / 输出为空 / 小于原文 30%）→ 记 warning，**不**覆盖旧 `polished.md`，本轮改用 `raw.md` 作为上传源
- 润色成功 → 覆盖写 `polished.md`，并写 `raw-checksum.json = {"raw_sha": raw_sha, "polished_at": "<ISO>"}`
- `preview=true` 只打印计划，不写文件

> 润色规则详见 [../wk-lark-wiki/references/polish-guidelines.md](../wk-lark-wiki/references/polish-guidelines.md)

## Step 6: update-or-create 上传飞书

上传源优先级：`polished.md` > `raw.md`（`no_polish=true` 或润色失败时回退）。

决策：

1. `unchanged=True`（Step 3 结论）且 `force=false` → 默认 `upload_status=skipped_unchanged`，不调用 lark-cli；仅当用户显式 `force=true` 时走 update 同步。
2. 读取 `<component>/.wk-lark-wiki/wiki-mapping.json.doc_id`。
3. 有 `doc_id`：`lark-cli docs +update --doc <doc_id> --mode overwrite --markdown-file <file> --as user`；失败则清 doc_id 走步骤 4。
4. 无映射：`lark-cli docs +search --query "<component>" --as user`；标题完全匹配则 update，否则 `lark-cli docs +create --title "<component>" --markdown-file <file> --wiki-node <wiki_node> --as user`。
5. 写回 `<component>/.wk-lark-wiki/wiki-mapping.json`：`{wiki_node, doc_id, doc_url, title, last_uploaded}`。
6. `preview=true` 只打印计划。

> 上传规则详见 [../wk-lark-wiki/references/step-upload.md](../wk-lark-wiki/references/step-upload.md)

## Step 7: Git 追踪（组件内）

对有更新的组件在其自身 git 仓库内 stage（只 stage，不自动 commit）：

```bash
cd <pods_dir>/<component>
git add .wk-lark-wiki/ 2>/dev/null || true
git status .wk-lark-wiki/ | head -10
```

**通知用户：** 缓存文件已在对应组件仓库内 stage，未自动 commit；由用户决定是否提交/推送。

## Step 8: 汇总报告

```
===== wk-lark-wiki-batch 汇总 =====
成功 N  未变跳过 U  非main跳过 M  失败 K
  (生成: 全量 G / 增量 I / 跳过 S)
  (润色: 新润 P / 命中缓存 C / 回退原文 F / 关闭 -)
  (上传: 新建 Cr / 覆盖更新 Up / 跳过未变更 Sk)

[成功]
  - <component>  →  <doc_url>  [gen=I polish=C upload=Up]
...

[跳过（未变更）]
  - <component>  最后上传: <last_uploaded>

[跳过（非 main 分支）]
  - <component>  原因: non-main branch: <branch>

[失败]
  - <component>  原因: <reason>
```

---

## 安全规则

> 以下规则优先级最高，不可违反。

1. **分支保护** — 只处理本地分支 `== main`
2. **自动 pull 用 ff-only** — 冲突即失败
3. **预览不触达飞书与文件系统** — `preview=true` 下禁止写任何 `.wk-lark-wiki/` 文件与调用任何写操作 lark-cli
4. **缓存与源码同进退** — `source-checksums.json` 仅在 `raw.md` 写入成功后更新，保证缓存一致性
5. **润色降级** — Haiku 失败不中断整批，不覆盖旧 `polished.md`，改用 `raw.md` 继续上传
6. **未变更跳过** — 默认 `force=false` 时，源码 hash 完全一致且已有映射则整组件跳过，节省 token / lark-cli 请求
7. **缓存入组件仓库** — `.wk-lark-wiki/` 不加 `.gitignore`，由各组件仓库版本化；由用户决定是否 commit/push
8. **update-or-create 不重复** — 上传必须先查后建
9. **Example 排除** — 源码 hash 与生成均排除 `Example/`

## 与 /wk-lark-wiki 的区别

| 维度 | `/wk-lark-wiki` | `/wk-lark-wiki-batch` |
|------|-----------------|-----------------------|
| 范围 | 单组件（对话式） | 全部 main 分支基础组件 |
| 组件来源 | 手动指定或自动从 .podspec | `mcp_app.bootstrap.discover_components` |
| 分支策略 | 校验当前分支 | 逐组件 pull + 筛 main |
| 缓存位置 | `mcp-ios-components/docs/api/` | `<pods_dir>/<component>/.wk-lark-wiki/`（各组件仓库内） |
| 增量粒度 | 章节级（内容 hash） | 组件级（源码 hash）+ 文件级（章节合并） |
| 润色 | 文档级（默认开启） | 文档级 Haiku（默认开启，可关） |
| 上传 | 单文档 update-or-create | 同一 wiki_node 批量 update-or-create + 未变跳过 |
