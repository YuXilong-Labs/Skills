# 报告模板与输出格式

> 本文件为 scan-clean-code Skill 的报告格式参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 报告结构

```markdown
# 代码清理审计报告

## 审计概要

| 项目 | 值 |
|------|-----|
| 审计模式 | model-fields / dead-code / unused-files / full |
| 目标文件 | path/to/TargetFile.h（model-fields 模式） |
| 工程根目录 | /path/to/project |
| 业务代码范围 | /path/to/project/Sources |
| 排除路径 | Pods, Vendor, ThirdParty |
| 语言 | ObjC / Swift / Mixed |
| 审计时间 | YYYY-MM-DD HH:MM |

## 统计汇总

| 分类 | 数量 | 占比 |
|------|------|------|
| 总审计项 | N | 100% |
| 活跃使用 | N | XX% |
| 可清理（高置信度） | N | XX% |
| 可清理（中置信度） | N | XX% |
| 需谨慎确认 | N | XX% |

**预估可清理代码行数：** ~NNN 行
**预估可节省文件大小：** ~NNN KB（仅 unused-files 模式）

---

## 可清理项（高置信度）

> 以下项目在工程范围内零活跃引用，可安全删除。

### 1. `fieldName` — ClassName.h:42

**类型：** 属性 / 方法 / 文件
**置信度：** 高
**原因：** 全工程无任何引用

**搜索证据：**
- 搜索 pattern: `\.fieldName\b`
  - 搜索范围: `project_root`（排除 Pods, Vendor）
  - 结果: 0 匹配
- 搜索 pattern: `@selector(fieldName)`
  - 结果: 0 匹配
- 搜索 pattern: `@"fieldName"`
  - 结果: 0 匹配
- KVC/KVO 检查: 未发现
- JSON 映射检查: 未在 modelCustomPropertyMapper 中出现
- NSCoding 检查: 未在 encodeWithCoder/initWithCoder 中出现

---

## 可清理项（中置信度）

> 以下项目仅被死代码引用或在废弃模块中，建议人工二次确认后删除。

### 1. `fieldName` — ClassName.h:58

**类型：** 属性
**置信度：** 中
**原因：** 仅被 `DeprecatedManager.m:123` 引用，而 `DeprecatedManager` 本身无活跃入口

**搜索证据：**
- 搜索 pattern: `\.fieldName\b`
  - 结果: 1 匹配
    - `DeprecatedManager.m:123` — `self.model.fieldName`
- DeprecatedManager 活跃状态: **死代码**（无入口调用）
- 调用链: `fieldName` ← `DeprecatedManager.processData` ← (无调用者)

---

## 需谨慎确认

> 以下项目存在动态调用可能性或无法完全静态分析，需人工确认。

### 1. `fieldName` — ClassName.h:75

**类型：** 属性
**原因：** 存在 KVC 引用风险
**风险详情：**
- 发现 `valueForKey:` 调用，但 key 为变量，无法静态确定是否引用了 `fieldName`
- 位置: `DataBinder.m:45` — `[obj valueForKey:keyString]`
**建议：** 检查 `DataBinder.m:45` 的 `keyString` 可能取值

---

## 活跃使用项

> 以下项目确认有活跃业务引用，应保留。

| # | 名称 | 文件:行号 | 引用数 | 主要引用位置 |
|---|------|-----------|--------|-------------|
| 1 | fieldName1 | Class.h:10 | 5 | ViewA.m, ServiceB.m, ... |
| 2 | fieldName2 | Class.h:15 | 3 | ControllerC.m, ... |
| ... | ... | ... | ... | ... |
```

---

## 2. 置信度定义

| 级别 | 条件 | 误删风险 |
|------|------|----------|
| **高置信度** | 全项目零引用 + 不涉及动态调用模式 + 非协议/父类要求 | 极低 |
| **中置信度** | 仅被已确认的死代码引用 / 引用极少且在废弃模块中 | 低 |
| **需谨慎确认** | 涉及 KVC/KVO / @selector 字符串构造 / 协议要求 / 反射 / 跨模块公开 | 需人工判断 |

---

## 3. 全量扫描（full 模式）汇总格式

```markdown
# 全量代码清理审计报告

## 总体统计

| 维度 | 总审计项 | 可清理 | 需确认 | 活跃 |
|------|----------|--------|--------|------|
| Model 字段 | N | N | N | N |
| 死代码（方法/函数） | N | N | N | N |
| 无用文件 | N | N | N | N |
| **合计** | **N** | **N** | **N** | **N** |

**预估可清理代码行数：** ~NNN 行
**预估可节省文件大小：** ~NNN KB

## 详细报告

### Part 1: Model 字段审计
(同 model-fields 模式输出)

### Part 2: 死代码检测
(同 dead-code 模式输出)

### Part 3: 无用文件检测
(同 unused-files 模式输出)

## 清理优先级建议

基于置信度和影响范围，建议按以下顺序清理：

1. **高置信度无用文件** — 直接删除，减小工程体积
2. **高置信度死代码** — 删除方法/函数定义
3. **高置信度 Model 字段** — 删除属性声明和相关代码
4. **中置信度项目** — 人工确认后批量清理
5. **需谨慎确认项目** — 逐个排查，不建议批量操作
```

---

## 4. 证据格式规范

每条证据必须包含：

```markdown
- 搜索 pattern: `<grep 正则表达式>`
  - 搜索范围: `<目录路径>`（排除 <排除列表>）
  - 结果: N 匹配
    - `<file>:<line>` — `<匹配的代码行>`（如有匹配）
```

要求：
- pattern 必须是实际执行的 grep 正则
- 搜索范围明确标注
- 匹配结果附带文件路径和行号
- 如果匹配数量 > 5，只列出前 5 条并注明总数

---

## 5. 注意事项

- 报告中的行号基于审计时的文件状态，如果文件在审计后被修改，行号可能偏移
- "活跃使用项"部分可根据数量酌情省略（>50 项时只显示统计数字）
- 报告不包含自动修复建议 — Skill 只负责识别，不负责修改
- 如果审计范围过大（>1000 个文件），建议分模块执行
