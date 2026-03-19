---
name: wk-review
description: |
  本地代码修改 Review 工具 — 以资深 iOS/移动端开发视角审查 git diff，
  关注逻辑 bug、crash 风险、内存泄漏、性能问题、线程安全、资源管理。
  采用 Agent 并行审查架构，每个文件/模块由独立 Agent 子进程审查，
  确保上下文隔离、审查专注、大 diff 不挤占主对话空间。
  所有结论附带准确行号和代码证据，分级输出，只读不改。
---

# WK-Review — 本地代码修改审查 Skill（Agent 并行架构，7 大维度）

## 架构概览

```
用户 → /wk-review → 主流程获取 diff + 解析文件列表
                         ↓
                   按文件/模块分组，并行派发 Review Agent
                         ↓（每个 Agent 独立上下文）
                   各 Agent 读取文件上下文 + 逐维度审查
                         ↓
                   主流程汇总各 Agent 结果 → 去重排序 → 输出报告
```

**Agent 模式的优势：**
- **上下文隔离** — 审查不受主对话历史干扰，Agent 有独立完整的上下文窗口
- **并行提速** — 多文件修改时并行派发，显著提升审查效率
- **角色专注** — 每个 Agent 以"资深 Code Reviewer"身份启动，只关注审查任务

---

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `scope` | 否 | `all` | diff 范围：`staged` / `unstaged` / `all` / `branch` / `commit:<hash>` |
| `focus` | 否 | 全部 | 聚焦领域（逗号分隔）：`logic,crash,memory,performance,thread,resource,bestpractice` |
| `severity` | 否 | `LOW` | 最低输出级别：`CRITICAL` / `HIGH` / `MEDIUM` / `LOW` |

---

## 审查维度（7 大类）

### 1. 逻辑 Bug（logic）
- 条件判断错误（边界值、off-by-one、取反遗漏）
- 流程控制错误（`return` vs `continue` vs `break`、早返回遗漏）
- 状态管理错误（状态未重置、状态不一致、竞态条件）
- 类型转换错误（隐式转换、精度丢失、强制解包）
- 算法逻辑错误（循环条件、递归终止、数组索引）

### 2. 本次修改对原有逻辑的影响（impact）
- 行为变更（函数返回值含义改变、参数语义变化）
- 副作用（新增的调用路径影响既有流程）
- 接口兼容性（公开 API 签名变化、协议方法变更）
- 默认值变化（枚举默认值、配置默认值、可选参数）
- 删除/修改被其他模块依赖的代码

### 3. Crash 风险（crash）
- 空值/nil 访问（强制解包 `!`、未检查的可选值）
- 数组越界（索引访问无边界检查、`first`/`last` 在空数组上）
- 类型强转失败（`as!` 替代 `as?`、`unsafeBitCast`）
- 线程安全 crash（非主线程 UI 操作、并发容器读写）
- 野指针/悬垂引用（`unowned` 引用已释放对象）

### 4. 内存问题（memory）
- 循环引用（delegate 未用 `weak`、闭包捕获 `self`）
- 闭包强引用链（嵌套闭包、`[weak self]` 缺失或无效）
- 通知/KVO 未移除（`addObserver` 无对应 `removeObserver`）
- 定时器强引用（`Timer`/`CADisplayLink` 持有 target）
- 大对象缓存未释放（图片缓存、数据缓冲区）
- 大内存分配（一次性加载大文件/大图到内存、未分片处理的大数据、`Data(contentsOf:)` 读取大文件）
- 持续内存增长（循环/递归中不断追加数据未释放、缓存无上限无淘汰策略、长生命周期对象持有不断增长的集合）
- 内存峰值（循环内创建大量临时对象无 `autoreleasepool`、大数组 `map`/`filter` 链产生多份中间拷贝）

### 5. 性能问题（performance）
- 主线程阻塞（同步网络/文件 IO、大数据解析）
- 不必要的重复计算（循环内的不变量、频繁的视图布局）
- 大数据拷贝（值类型大数组 copy、不必要的 `map`/`filter` 链）
- 过度绘制/布局（`layoutIfNeeded` 滥用、不透明视图叠加）

### 6. 资源管理（resource）
- 文件句柄未关闭
- 数据库连接未释放
- 定时器未 invalidate
- 通知未移除
- 音视频 session 未正确停止/释放

### 7. 语言最佳实践（bestpractice）
- **Swift**：
  - 可选值处理（优先 `guard let` / `if let`，避免 `!` 强制解包和 `as!` 强转）
  - 值类型 vs 引用类型选择（纯数据模型优先 `struct`，需要共享/继承时用 `class`）
  - 枚举建模（用 `enum` + associated value 替代松散的常量/字符串标记）
  - 协议导向设计（优先协议扩展提供默认实现，避免深层继承链）
  - 访问控制（合理使用 `private` / `fileprivate` / `internal`，避免不必要的 `public`）
  - 错误处理（优先 `throws` + `do-catch`，避免用可选值隐藏错误）
  - 集合操作（优先 `map` / `filter` / `compactMap`，避免手动 for 循环拼装）
  - 命名规范（方法名动词开头、布尔属性 `is`/`has` 前缀、工厂方法 `make` 前缀）
  - 现代 API 使用（优先 `Result` / `async-await`，避免嵌套回调金字塔）
- **Objective-C**：
  - 属性声明规范（`nonatomic` / `copy` / `strong` / `weak` 语义准确）
  - Nullability 标注完整（`NS_ASSUME_NONNULL_BEGIN/END` + 逐个 `nullable` 标注）
  - 轻量泛型使用（`NSArray<NSString *> *` 替代裸 `NSArray *`）
  - 枚举规范（`NS_ENUM` / `NS_OPTIONS` 替代裸 `enum`）
  - 分类命名规范（方法加前缀避免冲突、分类文件命名 `ClassName+CategoryName`）
  - Block typedef（复杂 Block 签名用 `typedef` 提高可读性）
  - 初始化模式（指定初始化器 `NS_DESIGNATED_INITIALIZER`、`instancetype` 返回类型）
  - 现代语法使用（字面量 `@[]` `@{}` `@()`、下标访问、`?:` 空合运算）
- **通用**：
  - 避免魔法数字/字符串（提取为命名常量或枚举）
  - 函数职责单一（单个函数不超过 50 行，做一件事）
  - 避免过深嵌套（超过 4 层缩进应考虑提前 return 或拆分）
  - 命名可读性（变量/函数名清晰表达意图，避免缩写和单字母命名）

---

## 严重程度分级

| 级别 | 标准 | 示例 |
|------|------|------|
| **🔴 CRITICAL** | 必定导致 crash 或数据损坏 | 数组越界、强制解包 nil、主线程死锁 |
| **🟠 HIGH** | 高概率导致问题，或影响核心功能 | 循环引用内存泄漏、逻辑分支错误、线程不安全 |
| **🟡 MEDIUM** | 潜在风险，特定条件下触发 | 性能隐患、资源未释放、边界未处理 |
| **🟢 LOW** | 代码质量/可维护性建议 | 命名不清晰、缺少注释、可优化的写法 |

---

## 核心工作流

```
Step 1（主流程）: 获取 diff，解析变更文件列表
    ↓
Step 2（主流程）: 按文件/模块分组，确定 Agent 派发策略
    ↓
Step 3（Agent 并行）: 并行派发 Review Agent，各自独立审查
    ↓
Step 4（主流程）: 汇总各 Agent 结果，去重排序
    ↓
Step 5（主流程）: 输出最终报告
```

### Step 1: 获取 diff 并解析文件列表

根据 `scope` 参数获取变更内容：

```bash
# scope=all（默认）：staged + unstaged
git diff HEAD --no-color

# scope=staged：仅暂存区
git diff --cached --no-color

# scope=unstaged：仅工作区
git diff --no-color

# scope=branch：当前分支 vs 主分支
git diff main...HEAD --no-color  # 或 master...HEAD

# scope=commit:<hash>：指定 commit
git show <hash> --no-color
```

**获取 diff 后，立即解析：**
1. 提取所有变更文件路径列表
2. 统计每个文件的变更行数（新增+删除）
3. 记录每个文件的 diff 内容（按文件分段保存）
4. 如果 diff 为空，提示用户并退出

### Step 2: 制定 Agent 派发策略

根据变更文件的数量和大小，确定分组策略：

**分组规则：**

| 条件 | 策略 |
|------|------|
| 变更文件 ≤ 3 个 | 每个文件单独一个 Agent，并行派发 |
| 变更文件 > 3 个 | 按关联性分组（同目录/同模块的文件归为一组），每组一个 Agent |
| 单文件 diff > 200 行 | 该文件单独一个 Agent（即使与其他文件同目录） |
| 变更文件 > 10 个 | 最多派发 5 个 Agent，将文件合理分配到 5 组内 |

**分组示例：**
```
变更文件：
  Engines/Agora/AgoraRtcEngine.swift      (+50/-10)
  Engines/Agora/AgoraExRtcEngine.swift    (+120/-30)  # >200行，单独
  Core/RTCEngineService.swift             (+20/-5)
  Common/RtcEnum.swift                    (+5/-0)

分组结果：
  Agent 1: AgoraExRtcEngine.swift        (大文件，单独)
  Agent 2: AgoraRtcEngine.swift          (同模块)
  Agent 3: RTCEngineService.swift + RtcEnum.swift (其余文件)
```

### Step 3: 并行派发 Review Agent

**使用 Agent 工具并行派发**，在同一条消息中发出所有 Agent 调用：

```
对每个分组，使用 Agent 工具：
- subagent_type: "code-reviewer" 或 "general-purpose"
- description: "Review {file_names}"
- prompt: 按下方 Agent Prompt 模板构造
```

> **关键：所有 Agent 调用放在同一条消息中发送，确保真正并行执行。**

#### Agent Prompt 模板

每个 Agent 的 prompt 必须包含以下完整内容（不要省略或引用外部文件，Agent 没有 Skill 上下文）：

```markdown
你是一位资深 iOS/移动端 Code Reviewer。请对以下代码修改进行专业审查。

## 审查规范

### 审查维度（按以下 7 大类逐一检查）

1. **逻辑 Bug（logic）**：条件判断错误、流程控制错误（return vs continue vs break）、状态管理错误、类型转换错误、算法逻辑错误
2. **修改对原有逻辑的影响（impact）**：行为变更、副作用、接口兼容性、默认值变化、删除被依赖的代码
3. **Crash 风险（crash）**：空值/nil 访问、数组越界、类型强转失败、线程安全 crash、野指针/悬垂引用
4. **内存问题（memory）**：循环引用、闭包强引用链、通知/KVO 未移除、定时器强引用、大对象缓存未释放、大内存分配（一次性加载大文件/大图）、持续内存增长（缓存无上限、集合不断增长）、内存峰值（循环内大量临时对象无 autoreleasepool）
5. **性能问题（performance）**：主线程阻塞、不必要的重复计算、大数据拷贝、过度绘制/布局
6. **资源管理（resource）**：文件句柄未关闭、数据库连接未释放、定时器未 invalidate、通知未移除、音视频 session 未正确停止
7. **语言最佳实践（bestpractice）**：Swift — 可选值处理、值/引用类型选择、协议导向、访问控制、现代 API；ObjC — 属性语义、Nullability、轻量泛型、NS_ENUM、分类规范；通用 — 魔法数字、函数职责单一、避免深嵌套、命名可读性

### 严重程度分级

- 🔴 CRITICAL：必定导致 crash 或数据损坏
- 🟠 HIGH：高概率导致问题，或影响核心功能
- 🟡 MEDIUM：潜在风险，特定条件下触发
- 🟢 LOW：代码质量/可维护性建议

### 语言特定要点

**Swift**：guard let / if let 完整性、[weak self] / [unowned self]、@escaping 闭包捕获、async/await Task 取消
**Objective-C**：nullable/nonnull 一致性、delegate weak、block __weak/__strong dance、@synchronized 线程安全、dealloc 清理

## 变更内容

{此处插入该 Agent 负责的文件 diff 内容}

## 审查要求

1. **用 Read 工具读取文件确认准确行号** — 不要从 diff 推算行号，必须用 Read 读取文件获得真实行号
2. **逐 hunk 审查** — 对每个 diff hunk，分析新增/修改/删除的代码
3. **上下文审查** — 读取变更行前后至少 20 行上下文，理解完整语境
4. **依赖审查** — 用 Grep 检查被修改的函数/方法是否有其他调用者
5. **只关注 diff 涉及的修改** — 不审查无关代码，不对既有设计提重构建议
6. **每个问题必须有代码证据** — 引用原始代码片段，不改写不省略
7. **如无问题则明确说明** — "该文件未发现问题"

{如果用户指定了 focus 参数，追加：}
8. **仅关注以下领域：{focus 参数值}** — 跳过其他维度

## 输出格式

**严格按以下 JSON 格式输出，便于主流程汇总：**

```json
{
  "files_reviewed": ["file1.swift", "file2.swift"],
  "issues": [
    {
      "severity": "CRITICAL|HIGH|MEDIUM|LOW",
      "category": "logic|impact|crash|memory|performance|resource|bestpractice",
      "title": "问题简述",
      "file": "完整文件路径",
      "line": 行号数字,
      "evidence": "引用的原始代码片段（保持原格式）",
      "reason": "为什么这是问题，具体分析",
      "fix": "修复建议或修复后的代码"
    }
  ],
  "impact_analysis": "本次修改的整体影响分析（行为变更、不对称操作、遗漏的错误处理等）",
  "no_issues_note": "如无问题，在此说明审查覆盖了哪些维度"
}
```

**注意：你的最终输出必须是纯文本形式的上述 JSON，不要包装在 markdown code block 中。主流程会解析这个 JSON。**
```

#### Agent Prompt 中的 Diff 内容嵌入

将 Step 1 中按文件分段保存的 diff 内容，嵌入到对应 Agent 的 prompt 中：

```markdown
## 变更内容

### 文件：BTRtcEngine/Engines/Agora/AgoraExRtcEngine.swift

\`\`\`diff
{该文件的 git diff 内容}
\`\`\`

### 文件：BTRtcEngine/Engines/Agora/AgoraRtcEngine.swift

\`\`\`diff
{该文件的 git diff 内容}
\`\`\`
```

### Step 4: 汇总 Agent 结果

收集所有 Agent 返回的结果后：

1. **解析各 Agent 的 JSON 输出** — 提取 issues 列表和 impact_analysis
2. **合并 issues** — 将所有 Agent 的 issues 合并到一个列表
3. **按 severity 排序** — CRITICAL > HIGH > MEDIUM > LOW
4. **去重** — 同文件同行号的相似问题合并（保留更详细的那条）
5. **过滤** — 如果用户指定了 `severity` 参数，过滤低于该级别的问题
6. **合并影响分析** — 将各 Agent 的 impact_analysis 整合为一段

### Step 5: 输出报告

使用 [output-format.md](references/output-format.md) 中的模板输出结构化报告。

将合并后的 issues 和影响分析，套入报告模板：
- 修改概要（文件列表、变更统计）
- 问题列表（按严重程度分级，附文件路径、行号、代码片段、修复建议）
- 影响分析（合并各 Agent 的分析结论）
- 总结与建议

---

## 行号准确性规则（最高优先级）

> ⚠️ 行号错误会严重降低 review 的可信度和可用性。

1. **行号必须来自实际文件**：使用 `Read` 工具读取文件时记录的行号，不要从 diff 输出中推算
2. **验证行号**：报告中引用的每一行代码，都必须与文件中该行号的实际内容一致
3. **使用 diff 行号定位，用 Read 行号确认**：先从 diff 中找到大致位置，再用 Read 工具确认准确行号
4. **引用代码必须是原文**：不要改写、省略或重新格式化引用的代码片段

---

## 安全规则

> ⚠️ 以下规则优先级最高，不可违反。

1. **只读不改** — Skill 只输出审查报告，不修改任何源文件，不执行 git 操作
2. **证据驱动** — 每个问题都必须引用具体代码片段作为证据，不允许凭印象下结论
3. **行号精确** — 报告中的行号必须与文件实际内容完全一致
4. **宁可误报不漏报** — 对于不确定的问题，标记为"需确认"并说明原因
5. **不做猜测性修复** — 修复建议必须基于对代码的实际理解，不确定时明确说明
6. **尊重原有设计** — 不对与本次修改无关的既有代码提出重构建议（除非存在明确 bug）
7. **Agent 只读权限** — 派发的 Agent 只使用 Read/Grep/Glob 工具，不使用 Write/Edit/Bash 修改文件

---

## 语言特定审查要点

### Swift

- `guard let` / `if let` 可选绑定是否完整
- `[weak self]` / `[unowned self]` 使用是否正确
- `@escaping` 闭包的捕获列表
- `async/await` 的 Task 取消和错误处理
- `actor` 隔离边界的正确性
- `Sendable` 合规性
- 值类型 vs 引用类型的选择是否合理

### Objective-C

- `nullable` / `nonnull` 标注与实际使用一致性
- `delegate` 属性是否为 `weak`
- `block` 中的 `__weak` / `__strong` dance
- 集合类型的泛型参数
- `@synchronized` / `dispatch_queue` 线程安全
- `dealloc` 中的清理是否完整

### 通用

- 错误处理路径的完整性
- 边界条件（空数组、nil、0、MAX_INT）
- 资源的对称获取与释放
- 并发访问的安全性

---

## 审查清单速查

> 详细清单见 [review-checklist.md](references/review-checklist.md)

**快速检查（每个 diff hunk 必查）：**
- [ ] 是否有强制解包（`!`）无保护
- [ ] 是否有数组索引访问无边界检查
- [ ] 是否有闭包未使用 `[weak self]`（应该用的场景）
- [ ] 是否有 `return` / `continue` / `break` 使用错误
- [ ] 是否有条件判断遗漏分支
- [ ] 是否有类型强转可能失败
- [ ] 本次修改是否改变了既有函数的行为语义
- [ ] 是否符合语言最佳实践（Swift/ObjC 惯用写法、命名规范）

---

## 输出格式

报告使用 Markdown 格式，详见 [output-format.md](references/output-format.md)。

---

## Agent 异常处理

- **Agent 返回非 JSON** — 尝试从返回文本中提取问题信息，手动构造 issues 列表
- **Agent 超时/失败** — 在报告中标注"该文件审查未完成"，建议用户单独对该文件执行 `/wk-review`
- **Agent 结果解析失败** — 将原始返回内容附在报告末尾，供用户参考
