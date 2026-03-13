---
name: ios-component-reuse
description: |
  iOS 组件库复用工作流 — 选型、实现、审查、迁移阶段强制执行"先检索组件再行动"，
  输出证据驱动的决策。依赖 MCP ios-components server。
  支持 4 种模式：selection / implementation / review / migration。
---

# iOS Component Reuse — 组件复用工作流 Skill

## 前置要求

- MCP `ios-components` server 已连接并可用
- 工具可用性确认：首次使用时调用 `get_tool_docs(tool_name="search_component", format="json")` 验证

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `mode` | 否 | `implementation` | 工作模式：`selection` / `implementation` / `review` / `migration` |
| `requirement` | 是 | — | 需求描述、PR 链接、迁移目标等（自然语言） |

## 模式路由

| 触发信号 | 对应 mode |
|----------|-----------|
| "先做选型/方案评估""给我主备方案""组件化技术方案" | `selection` |
| "实现/开发/编码""按组件化规范""复用现有组件写" | `implementation` |
| "review 这个 PR""检查重复造轮子""发布前审查" | `review` |
| "替换旧封装""迁移到基础组件""统一替换" | `migration` |

> 同时出现多个信号时，按 selection → review → migration → implementation 优先级选择。

---

## 各模式详解

### selection — 组件选型评估

**适用场景：** 需求评审、技术方案阶段，识别可复用组件并输出候选矩阵与主备方案。

**触发信号：**
- "先做组件化选型/方案评估"
- "这个需求要不要新增组件"
- "给我主方案/备选方案"

**排除信号：**
- 明确要求直接写代码（→ `implementation`）
- 明确要求替换旧实现（→ `migration`）
- 明确要求 PR 审查（→ `review`）

**工作流：**
1. 需求拆解 — 目标、约束（iOS 版本/性能/稳定性/工期）、能力点
2. 多轮检索 — 每个能力点 3-6 轮 `search_component`
3. 候选验证 — `get_component_api` + `get_class_detail` + `find_usage_example`
4. 方案输出 — 候选矩阵、主/备/不建议方案、风险与落地建议

**输出契约：**
1. 需求背景（目标 + 约束）
2. 能力拆解
3. 候选组件矩阵（必须含证据列）
4. 推荐方案（主方案 / 备选 / 不建议及原因）
5. 落地建议（依赖边界 / 测试重点 / 回滚策略）

**质量门槛：**
- 只给结论无证据 → 不合格
- 未给主/备/不建议三类方案 → 不合格
- 无检索证据就建议新建组件 → 不合格

> 输出模板与决策规则详见 [output-selection.md](references/output-selection.md)

---

### implementation — 复用优先实现

**适用场景：** 实现页面、功能、接口时，先检索现成能力再编码，输出可审计的复用证据。

**触发信号：**
- 实现/开发/编码/build 某个 iOS 页面、功能、接口
- 明确提到"复用现有组件 / 不要重复造轮子"
- 要求产出代码

**排除信号：**
- 纯方案评审/选型（→ `selection`）
- 纯迁移/替换既有实现（→ `migration`）
- 纯 PR 审查（→ `review`）

**工作流：**
1. 拆解需求能力点
2. 多轮检索（JSON-first，3-6 轮）
3. 候选确认（证据落地到 API）
4. 实现落地（只使用已确认组件 API）
5. 实现后自检

**输出契约：**
1. 检索摘要（能力点 + 关键词轮次矩阵）
2. 证据链
3. 选型决策表
4. 代码实现
5. 自检结论

**质量门槛：**
- 未进行多轮检索（<3 轮）→ 不合格
- 未提供 `get_component_api` 证据 → 不合格
- 直接手写已有基础能力 → 不合格

> 输出模板与自检清单详见 [output-implementation.md](references/output-implementation.md)

---

### review — PR 组件复用审查

**适用场景：** PR review / 变更审查 / 发布前质量门禁，识别"可复用却未复用"的改动。

**触发信号：**
- "review 这个 PR，检查是否重复造轮子"
- "发布前审查是否有平行封装"

**排除信号：**
- 明确要求直接实现功能（→ `implementation`）
- 明确要求设计方案/选型（→ `selection`）
- 明确要求迁移改造（→ `migration`）

**工作流：**
1. 提取疑似重复点（从 PR diff/变更描述中识别）
2. 多轮检索复用证据（JSON-first）
3. 组件证据确认
4. 输出审查结论

**输出契约：**
1. 审查结论（通过 / 需整改 / 阻塞）
2. 问题项（位置、描述、证据链、修复建议、严重级别）
3. 豁免项（如有）
4. 建议动作

**质量门槛：**
- 只说"重复造轮子"但无证据 → 不合格
- 中高风险问题无替换建议 → 不合格
- 阻塞判定不符合 severity-rubric → 不合格

> 输出模板与严重级别规则详见 [output-review.md](references/output-review.md)

---

### migration — 重复实现迁移

**适用场景：** 将业务中的重复基础能力迁移到基础组件，分批替换并给出验证与回滚策略。

**触发信号：**
- "把自定义 URLSession/图片缓存/弹窗替换成基础组件"
- "迁移到基础网络组件/统一 UI 组件"

**排除信号：**
- 纯新增功能实现（→ `implementation`）
- 纯方案评审（→ `selection`）
- 纯 PR 审查（→ `review`）

**工作流：**
1. 识别重复实现点
2. 多轮检索目标组件（JSON-first）
3. 建立迁移映射
4. 识别已有迁移模式（`find_usage_example`）
5. 输出分批替换计划 + 验证/回滚

**输出契约：**
1. 重复实现识别结果
2. 迁移映射表（旧调用 → 目标 API + 差异 + 风险 + 批次）
3. 分批改造计划（步骤 + 验证 + 回滚触发条件）
4. 风险与限制

**质量门槛：**
- 无映射表直接建议全量替换 → 不合格
- 无验证与回滚策略 → 不合格
- 引入新的平行基础层 → 不合格

> 输出模板与迁移 playbook 详见 [output-migration.md](references/output-migration.md)

---

## 核心工作流（所有模式共享）

所有模式遵循统一的 4 步检索验证流程：

```
需求拆解 → 多轮检索（JSON-first） → 候选验证（API 证据） → 结构化输出
```

### JSON-first 策略

- 所有检索默认 `search_component(format="json", limit=5)`，小步多轮收敛
- 至少 3 轮：中文语义词 → 英文同义词 → 类名/类型词
- `find_usage_example` 仅摘取最相关引用位置，不整段粘贴

### 失败恢复

| 场景 | 处理 |
|------|------|
| 无命中 | 补同义词、类名词再搜（≥2 轮），输出"已检索范围 + 未命中" |
| 命中过多 | 用更窄关键词或 `kind` 限制，对前 2-3 候选做 API 对比 |
| `api_only` 限制 | 用 `get_component_api` + `get_class_detail` + `find_usage_example` 替代，标注"证据受限" |
| 工具异常 | 调用 `get_tool_docs` 确认参数，降级 text 格式，不虚构 API |

### 证据最小集（必须满足）

每个关键结论至少包含：
- 1 组 `search_component` 命中证据（关键词 + 命中项）
- 1 次 `get_component_api` 证据（确认 API 范围）
- 1 次 `get_class_detail` / `read_source` / `find_usage_example` 佐证

> 工作流详细说明见 [common-workflow.md](references/common-workflow.md)
> 关键词策略见 [keyword-strategy.md](references/keyword-strategy.md)

---

## 通用质量门槛

- 未进行多轮检索（<3 轮）→ 任何模式均不合格
- 无 `get_component_api` 证据就下结论 → 不合格
- 建议新建组件但未穷尽检索 → 不合格
- 输出缺少证据列/证据链 → 不合格

## 候选排序优先级

1. Category / Extension（调用自然，侵入小）
2. Protocol / 统一基类（替换成本可控）
3. Helper / Utility（兜底选择）
