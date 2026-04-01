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

使用 Bash 工具自动检测运行上下文和当前分支：

```bash
# 1. 检测上下文类型
if [ -f tools/generate_api_docs.py ] && [ -d .cache ]; then
    echo "CONTEXT=mcp-ios-components"
elif ls *.podspec 1>/dev/null 2>&1; then
    echo "CONTEXT=cocoapods-component"
    echo "COMPONENT=$(ls *.podspec | head -1 | sed 's/.podspec$//')"
else
    echo "ERROR: 非 mcp-ios-components 目录，也未找到 .podspec 文件"
fi

# 2. 分支校验（generate/full 模式必须在 main/master）
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
echo "BRANCH=$current_branch"
```

**校验规则：**
- 上下文检测失败 → 报错并终止
- `generate` / `full` 模式下 `$current_branch` 不是 `main` 或 `master` → 报错：`"文档生成仅允许在 main/master 分支执行。当前分支: $current_branch"`
- `polish` / `upload` 模式不限制分支

**设置上下文变量供后续步骤使用：**
- `CONTEXT_TYPE`：`mcp-ios-components` 或 `cocoapods-component`
- `COMPONENT_NAME`：自动检测或用户参数
- `DOCS_DIR`：`docs/api/`（相对于项目根目录）

### Step 1: 环境校验

根据检测到的上下文类型，分两条路径校验：

**mcp-ios-components 上下文：**

```bash
# 必须在 mcp-ios-components 项目目录下
test -f tools/generate_api_docs.py || echo "错误：未找到 tools/generate_api_docs.py"
test -f .cache/index.json || echo "错误：索引缓存不存在，请先运行 MCP Server 构建索引"

# upload/full 模式需要 lark-cli
if [[ "$mode" == "full" || "$mode" == "upload" ]]; then
    lark-cli --version 2>/dev/null || echo "错误：lark-cli 未安装"
fi
```

**CocoaPods 组件上下文：**

1. 确认 `.podspec` 文件存在
2. 调用 `search_component(component_name, format="json", limit=3)` 验证 MCP 索引可用
   - 返回空结果 → 报错：`"组件 {name} 未被 MCP 索引，请先将组件添加到 ios-components 索引"`
3. 检查 `docs/api/` 目录，不存在则创建
4. upload/full 模式检查 `lark-cli` 可用

**校验清单：**
- [ ] 上下文类型已确定
- [ ] 组件名已确定（自动或手动）
- [ ] MCP 工具可用（CocoaPods 上下文）或 Python 脚本可用（mcp 上下文）
- [ ] `lark-cli` 可用（upload/full 模式）
- [ ] `docs/api/` 目录就绪

### Step 2: 增量文档生成（modes: `full`, `generate`）

#### 2.1 源码增量检测

计算源码文件 hash，与上次生成时的记录比对：

**CocoaPods 组件上下文：**
```bash
# 排除 Example/ Pods/ .git/ DerivedData/ 目录
find . \( -name "*.h" -o -name "*.m" -o -name "*.mm" -o -name "*.swift" \) \
    ! -path "*/Example/*" ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/DerivedData/*" \
    -exec md5 -r {} \; | sort
```

**mcp-ios-components 上下文：**
```bash
# 计算指定组件的源码 hash
find <pods_dir>/<component> -name "*.h" -o -name "*.m" -o -name "*.swift" | \
    xargs md5 -r | sort
```

与 `docs/api/.source-checksums.json` 比对：
- hash 不同 → 源文件有变更，对应类文档需要重新生成
- 新文件 → 需要生成
- hash 相同 → 跳过

> **首次运行**（无 `.source-checksums.json`）→ 全量生成所有文档。

#### 2.2 文档生成 — mcp-ios-components 路径

使用 Bash 工具执行生成脚本。输出重定向到临时文件：

```bash
python tools/generate_api_docs.py --pods-dir <pods_dir> [--component <name>] [--ai-fill] \
    2>&1 | tee /tmp/wk-lark-wiki-gen.log | tail -30
```

#### 2.3 文档生成 — CocoaPods 组件路径

Claude Code 使用 MCP ios-components 工具直接生成文档：

1. **获取 API 列表**：调用 `get_component_api(component_name)`，获取完整公开 API（按文件分组）
2. **逐类获取详情**：对每个类/协议调用 `get_class_detail(component_name, classname)`
   - 批量调用：每条消息中并行发出多个 `get_class_detail` 调用（提升效率）
3. **补充实现细节**：对复杂初始化器、枚举值、核心方法调用 `read_source(component_name, file, start, end)` 获取源码
4. **获取调用示例**：调用 `find_usage_example(component_name)` 获取其他组件的真实使用样例
5. **组装文档**：按 [lark-doc-template.md](references/lark-doc-template.md) 模板结构组装 Markdown
6. **写入文件**：使用 Write 工具写入 `docs/api/<ComponentName>.md`

**关键约束：**
- 排除 `Example/` 目录下的所有文件
- 只处理公开 API（public header 中的声明）
- 仅对增量检测标记为"需重新生成"的类执行上述流程

#### 2.4 生成文件目录架构图

每份组件文档必须在 `# 组件名` 和摘要之后、`## 快速开始` 之前包含一个 `## 文件目录` 章节。

使用 Bash 工具获取目录结构：
```bash
# CocoaPods 组件
tree -I "Example|Pods|.git|DerivedData|__pycache__" --dirsfirst -L 3 --charset ascii

# mcp-ios-components（指定组件目录）
tree <pods_dir>/<component> -I "Example|.git" --dirsfirst -L 3 --charset ascii
```

**文件目录格式要求：**
- 只展示源文件（`.h`、`.m`、`.mm`、`.swift`）和关键资源目录
- 每个文件/目录后用 `# 注释` 说明用途（从文件名、���部注释或内容推断）
- 目录深度最多 3 层，超过用 `...` 省略
- 空目录不展示

示例：
```
## 文件目录

```
BTBaseKit/
├── Classes/
│   ├── Core/
│   │   ├── BTBaseObject.h          # 基类定义，所有组件的根类
│   │   ├── BTBaseObject.m          # 基类实现，KVO/通知等基础能力
│   │   └── BTSingleton.h           # 单例宏定义
│   ├── Utils/
│   │   ├── BTStringUtils.h         # 字符串工具（加密、截取、校验）
│   │   └── BTDeviceInfo.h          # 设备信息采集（型号、系统、网络）
│   └── Categories/
│       ├── NSString+BTExtension.h  # NSString 扩展（URL 编码、MD5）
│       └── UIView+BTLayout.h       # UIView 布局便捷方法
└── BTBaseKit.podspec
```
```

#### 2.5 更新源码 checksums

生成完成后，使用 Write 工具写入 `docs/api/.source-checksums.json`：

```json
{
  "updated_at": "2026-04-01T12:00:00",
  "context": "cocoapods-component",
  "component": "BTBaseKit",
  "files": {
    "Classes/Core/BTBaseObject.h": "a1b2c3d4...",
    "Classes/Utils/BTStringUtils.h": "e5f6a7b8..."
  }
}
```

**生成后确认：**
1. 列出 `docs/api/` 下新生成/更新的 .md 文件
2. 报告：生成 N 个、跳过 M 个（未变更）、总 API 数

如果 `mode=generate`，跳过 Step 3-5，直接执行 Step 6-7。

### Step 3: 差异检测（modes: `full`, `polish`）

判断首次润色还是增量润色：

**3.1 检查 `docs/api/.checksums.json` 是否存在**

不存在 → **首次润色**，所有文件需处理。

**3.2 计算当前文档 MD5 hash**

```bash
cd docs/api && find . -name "*.md" ! -name "index.md" -exec md5 -r {} \; | sort
```

**3.3 比对 hash，确定变更文件列表**

读取 `docs/api/.checksums.json`，与当前 hash 比较：
- hash 不同 → 文档有变更，需要润色
- 新文件 → 需要润色
- hash 相同 → 跳过，保留 `docs/api/polished/` 中已有润色版本

**3.4 对变更文件做章节级 diff**

按 `## ` 二级标题拆分为章节，仅标记内容有变化的章节需要润色。

> 首次润色时跳过章节 diff，直接全量润色。

### Step 4: AI 深度润色（modes: `full`, `polish`）

Claude Code 直接阅读文档并改写，遵循 [polish-guidelines.md](references/polish-guidelines.md) 中的规则。

#### 4.1 源码验证润色（新增，最高优先级）

**润色前必须读源码验证描述准确性：**

1. 对关键 API（初始化方法、核心业务方法、状态管理属性），使用 MCP `read_source(component, file, start, end)` 读取实现代码
2. 根据实际实现逻辑修正文档描述：
   - 注释说"同步"但实现为异步 → 修正
   - 参数有合法值范围限制（如 0.0-1.0）→ 补充
   - 方法有线程安全要求 → 标注
   - 调用有前置条件（如必须先 setup）→ 说明
3. 对 `*暂无说明*` 条目，结合源码实现生成准确描述

**润色优先级：** 源码实现 > 注释声明 > 方法名推断

#### 4.2 首次全量润色

对每个组件文档文件：

1. 使用 Read 工具读取 `docs/api/<component>.md`
2. 按 [polish-guidelines.md](references/polish-guidelines.md) 规则改写：
   - 确保文件目录架构图完整（含注释）
   - 重组文档结构（添加概览表格、优化章节顺序）
   - 结合源码补充缺失描述
   - 优化飞书渲染格式（表格、引用块、代码块标签）
   - 统一样式（emoji、标题层级、分隔线）
3. 使用 Write 工具写入 `docs/api/polished/<component>.md`
4. 对照 [lark-doc-template.md](references/lark-doc-template.md) 模板检查格式一致性

#### 4.3 增量润色

对每个有变更的文件：

1. 读取已有润色版本 `docs/api/polished/<component>.md`
2. 读取新生成的原始版本 `docs/api/<component>.md`
3. 定位变更章节（Step 3.4 确定的）
4. 仅对变更章节执行源码验证 + 格式润色
5. 替换已有润色文档中对应章节
6. 写回 `docs/api/polished/<component>.md`

> **关键约束：** 未变更的章节保持原样，不重新润色。

#### 4.4 大文档并行处理

当单个组件 API 数量 > 100 时，使用 Agent 子进程并行润色：

```
按 ## 二级标题拆分，每 3-5 个章节为一组，派发一个 Agent：
- subagent_type: "general-purpose"
- description: "润色 {component} 的 {class1, class2, ...} 章节"
- prompt: 包含润色规则 + 源码验证要求 + 待润色章节内容

所有 Agent 调用放在同一条消息中发送，确保并行执行。
```

主流程收到所有 Agent 结果后，按章节顺序拼接，写入润色文件。

#### 4.5 更新 checksums

润色完成后，使用 Write 工具更新 `docs/api/.checksums.json`：

```json
{
  "updated_at": "2026-04-01T12:00:00",
  "files": {
    "BTBaseKit-底层基类、工具类.md": {
      "hash": "abc123...",
      "polished": true
    }
  }
}
```

### Step 5: 上传飞书 — update-or-create（modes: `full`, `upload`）

上传润色后的文档（优先 `docs/api/polished/`，若不存在则用 `docs/api/`）。

#### 5.1 加载 wiki 映射

```bash
cat docs/api/.wiki-mapping.json 2>/dev/null || echo "{}"
```

#### 5.2 逐文件上传（update-or-create 逻辑）

对每个待上传的 .md 文件，按以下决策流程执行：

```
1. 从 .wiki-mapping.json 查找该组件的 doc_id

2. 如果有 doc_id（曾经上传过）：
   → 读取文件内容到临时文件
   → 执行：lark-cli docs +update --doc <doc_id> --mode overwrite --markdown-file <tmp_file> --as user
   → 如果 update 成功 → 记录结果，继续下一个
   → 如果 update 失败（文档已被删除等）→ 清除映射，进入步骤 3

3. 如果没有映射（首次上传或映射失效）：
   → 执行搜索：lark-cli docs +search --query "<组件名>" --as user
   → 解析搜索结果，查找 title 完全匹配的文档
   → 如果找到匹配文档：
     → 提取 doc_id
     → 执行：lark-cli docs +update --doc <doc_id> --mode overwrite --markdown-file <tmp_file> --as user
   → 如果未找到匹配：
     → 执行：lark-cli docs +create --title "<title>" --markdown-file <tmp_file> --wiki-node <wiki_node> --as user
     → 从创建结果中提取 doc_id

4. 更新 .wiki-mapping.json 中该组件的 doc_id 和 last_uploaded
```

**lark-cli +update 的 markdown 传递方式：**
- 短内容（< 5000 字符）：`--markdown <content>`
- 长内容：写入临时文件，使用 `--markdown-file <tmp_file>`

#### 5.3 保存 wiki 映射

使用 Write 工具更新 `docs/api/.wiki-mapping.json`：

```json
{
  "wiki_node": "wikcnXXXX",
  "updated_at": "2026-04-01T12:00:00",
  "mappings": {
    "BTBaseKit": {
      "doc_id": "doccnYYYY",
      "doc_url": "https://xxx.feishu.cn/wiki/...",
      "title": "BTBaseKit-底层基类、工具类",
      "last_uploaded": "2026-04-01T12:00:00"
    }
  }
}
```

#### 5.4 预览模式

`preview=true` 时，对每个文件输出将要执行的操作（create / update + doc_id + title），但不执行任何 lark-cli 命令。

### Step 6: Git 追踪（所有模式）

生成/润色/上传完成后，确保文档纳入 git 管理：

```bash
# 检查 docs/api/ 是否被 .gitignore 排除
if grep -q "docs/api" .gitignore 2>/dev/null; then
    echo "WARNING: docs/api/ 在 .gitignore 中，建议移除该排除规则"
fi

# Stage 文档目录（包含元数据文件）
git add docs/api/
git add docs/api/.checksums.json docs/api/.source-checksums.json docs/api/.wiki-mapping.json 2>/dev/null

# 展示变更状态
git status docs/api/
```

**通知用户：** 文档已 stage 到暂存区，但未自动 commit。用户可查看变更后手动提交。

### Step 7: 汇总报告

输出结构化报告：

```markdown
## wk-lark-wiki 执行报告

**模式：** {mode}
**上下文：** {mcp-ios-components / cocoapods-component}
**分支：** {branch_name}
**时间：** {timestamp}

### 处理概况
- 上下文类型：{type}
- 组件：{component_name}
- 源文件变更：{changed_count} 个（跳过 {skipped_count} 个未变更）
- 文档生成：{generated} 个
- 增量润色：{polished} 个（跳过 {polish_skipped} 个未变更）
- 飞书上传：更新 {updated} 个 / 新建 {created} 个
- Git 追踪：{staged_count} 个文件已 stage

### 文件明细
| 组件 | 生成 | 润色 | 上传 | 飞书链接 |
|------|------|------|------|----------|
| BTBaseKit | 增量更新 | 3 章节润色 | 更新已有 | [链接](url) |
| BTNetwork | 无变更，跳过 | 跳过 | 跳过 | [链接](url) |

### 问题与建议
{如有错误、警告或优化建议，列出}
```

---

## 安全规则

> ⚠️ 以下规则优先级最高，不可违反。

1. **只读源码** — Skill 只读取源码和索引生成文档，不修改任何源文件
2. **润色输出隔离** — 润色结果写入 `docs/api/polished/`，不覆盖原始生成文档
3. **分支保护** — `generate` / `full` 模式仅在 `main` / `master` 分支执行，其他分支报错终止
4. **更新优先** — 上传飞书时先查已有文档再决定 update 或 create，避免重复创建
5. **预览模式** — `preview=true` 时仅展示操作计划，不实际执行上传/更新
6. **输出重定向** — 所有可能产生大量输出的命令重定向到临时文件，对话中只展示末尾摘要
7. **源��润色准确性** — 润色描述必须与源码实现一致，不臆测功能；不确定时标注"需确认"
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
