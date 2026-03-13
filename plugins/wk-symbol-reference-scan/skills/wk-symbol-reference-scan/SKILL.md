---
name: wk-symbol-reference-scan
description: |
  iOS 工程全局符号引用扫描工具 — 覆盖源码、Framework Headers、二进制 strings 三条路径。
  支持 single/batch/related 三种模式，输出结构化 Markdown 表格报告。
  证据驱动、只读不修改、多源并行搜索。
---

# Symbol Reference Scan — 符号引用扫描 Skill

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `keywords` | 是 | — | 待搜索关键词，逗号分隔 |
| `project_root` | 否 | `.` | 工程根目录 |
| `scope` | 否 | `all` | 搜索范围：`source_only` / `binary_only` / `all` |
| `exclude_paths` | 否 | `Build,DerivedData,.git` | 逗号分隔的排除路径 |
| `include_third_party` | 否 | `false` | 是否包含三方 SDK 结果 |
| `output_file` | 否 | — | 报告输出文件路径（不指定则直接输出到对话） |
| `mode` | 否 | `single` | 扫描模式，见下方说明 |
| `case_sensitive` | 否 | `false` | 是否区分大小写 |

## 扫描模式

### 1. `single` — 单关键词扫描

针对单个关键词，在所有搜索路径中查找引用。

**适用场景：** 快速确认某个符号在工程中的使用情况。

### 2. `batch` — 批量扫描

对多个关键词逐一扫描，末尾附加综合关联关系表。

**适用场景：** 同时排查多个相关符号、批量清理评估。

### 3. `related` — 关联扫描

自动扩展相关符号后批量扫描。扩展策略：
- 输入 `FeatureX` → 自动扩展 `FeatureXManager`、`FeatureXConfig` 等变体词
- 输入类名前缀 → 扩展所有同前缀符号
- 末尾输出跨关键词关系分析

**适用场景：** 功能下线评估、模块影响范围分析。

---

## 核心工作流

无论哪种模式，都遵循统一的 5 步流程：

```
参数解析 → 并行多源搜索 → 结果解析分类 → 去重合并 → 报告生成
```

### Step 1: 参数解析

1. 解析 `keywords`，按逗号拆分为关键词列表
2. 确定搜索范围（`scope`）和排除路径
3. `related` 模式下自动扩展关键词列表
4. 确认 `case_sensitive` 设置

### Step 2: 并行多源搜索

对每个关键词，并行执行以下搜索路径（根据 `scope` 过滤）：

#### 路径 1: 源码搜索（Grep）

搜索工程源码文件（`.h`, `.m`, `.mm`, `.swift`, `.pch`, `.xib`, `.storyboard`, `.plist`, `.pbxproj`）。

```bash
# 使用 Grep 工具搜索
pattern: <keyword>
glob: "*.{h,m,mm,swift}"
path: <project_root>
```

排除 `exclude_paths` 中的目录。

#### 路径 2: Framework Headers 搜索（Grep）

搜索 Pods/Carthage/Vendor 等目录下的 `.framework/Headers/` 和 `.xcframework/**/Headers/`。

```bash
# Headers 搜索
pattern: <keyword>
path: <project_root>/Pods
glob: "**/*.h"
```

#### 路径 3: Framework 二进制搜索（strings）

对 `.framework` 和 `.xcframework` 中的二进制文件执行 `strings` 命令。

```bash
# 查找二进制文件
find <project_root> -path "*.framework/*" -type f ! -name "*.h" ! -name "*.plist" ! -name "*.modulemap" | head -200

# 对每个二进制执行 strings 并过滤
timeout 30 strings <binary_path> | grep -i <keyword>
```

#### 路径 4: 静态库搜索（strings/nm）

对 `.a` 文件执行 `strings` 或 `nm` 命令。

```bash
find <project_root> -name "*.a" -type f | head -50
timeout 30 strings <lib_path> | grep -i <keyword>
```

> 详细搜索策略见 [search-strategy.md](references/search-strategy.md)

### Step 3: 结果解析分类

对搜索结果按符号类型分类：

| 模式 | 类型 | 示例 |
|------|------|------|
| `_OBJC_CLASS_$_XXX` | class_definition | 类定义/引用 |
| `_OBJC_IVAR_$_Class._field` | ivar | 实例变量 |
| `-[Class method]` / `+[Class method]` | method | 实例/类方法 |
| `T@"Type",*,V_field` | property_encoding | 属性类型编码 |
| `@property ...` | property | 属性声明 |
| `#import` / `#include` / `@import` | import | 导入语句 |
| `// ...keyword...` / `/* ...keyword... */` | commented_out | 注释引用 |
| 其余匹配 | reference | 一般引用 |

**业务 vs 三方分类规则：**

| 前缀 | 分类 |
|------|------|
| `BT*` / `PLA*` / `Pop*` | 业务模块 |
| 其余 | 三方 SDK |

> 前缀列表为可配置默认值，可根据实际项目调整。

### Step 4: 去重合并

- **去重维度：** (模块, 类, 符号名, 符号类型) 四元组
- **xcframework 多架构合并：** 同一 xcframework 下不同架构（arm64/x86_64）的相同符号只保留一条
- **来源标注：** 保留最具体的来源（源码 > Header > 二进制 strings）

### Step 5: 报告生成

输出结构化 Markdown 报告。

> 完整格式模板见 [output-format.md](references/output-format.md)

---

## 安全规则

> 以下规则优先级最高，不得违反。

1. **只读操作** — 不修改任何文件，不执行写入操作
2. **strings 超时保护** — 单次 `strings` 命令超时 30 秒，超时则跳过并记录
3. **证据驱动** — 每条结果必须标注来源（源码 / Header / 二进制 strings）
4. **未搜二进制不可报"无引用"** — 当 `scope=all` 时，必须完成二进制搜索后才能下结论
5. **未去重不可输出** — 输出前必须执行四元组去重
6. **每行必须有来源标注** — 表格每行必须注明搜索来源
7. **输出重定向** — `strings` 等大输出命令重定向到临时文件，对话中只展示摘要

---

## 质量门槛

- [ ] 所有搜索路径（源码 + Headers + 二进制）均已覆盖
- [ ] 结果已按四元组去重
- [ ] 每行结果均有来源标注
- [ ] 统计数字与明细表一致
- [ ] batch/related 模式包含跨关键词关系分析表
- [ ] `output_file` 指定时报告已写入文件

---

## 输出格式

报告使用 Markdown 格式，包含以下部分：
1. 扫描概要（关键词、范围、模式、时间）
2. 统计汇总（各来源命中数、模块分布）
3. 每关键词引用明细表
4. 跨关键词关系分析表（batch/related 模式）

> 完整格式模板见 [output-format.md](references/output-format.md)
