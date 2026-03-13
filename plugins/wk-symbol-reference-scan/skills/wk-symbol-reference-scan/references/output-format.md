# 报告模板与输出格式

> 本文件为 symbol-reference-scan Skill 的报告格式参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 报告整体结构

```markdown
# 符号引用扫描报告

## 扫描概要

| 项目 | 值 |
|------|-----|
| 关键词 | keyword1, keyword2, ... |
| 扫描模式 | single / batch / related |
| 工程根目录 | /path/to/project |
| 搜索范围 | all / source_only / binary_only |
| 排除路径 | Build, DerivedData, .git |
| 大小写敏感 | 是 / 否 |
| 包含三方 SDK | 是 / 否 |
| 扫描时间 | YYYY-MM-DD HH:MM |

## 统计汇总

| 关键词 | 源码 | Header | 二进制(strings) | 合计 |
|--------|------|--------|------------------|------|
| keyword1 | N | N | N | N |
| keyword2 | N | N | N | N |
| **合计** | **N** | **N** | **N** | **N** |

### 模块分布

| 模块 | 分类 | 命中数 |
|------|------|--------|
| ModuleA | 业务 | N |
| ModuleB | 业务 | N |
| ThirdPartySDK | 三方 | N |

---

## keyword1 引用明细

| # | 模块 | 类/文件 | 符号/属性 | 类型 | 来源 | 描述 |
|---|------|---------|-----------|------|------|------|
| 1 | ModuleA | ClassA | propertyName | property | 源码 | ClassA.h:42 |
| 2 | ModuleB | ClassB | -[ClassB methodName] | method | 二进制(strings) | libModuleB.framework |
| 3 | SDKName | SDKClass | _OBJC_CLASS_$_SDKClass | class_definition | 二进制(strings) | SDK.framework |
| ... | ... | ... | ... | ... | ... | ... |

---

## keyword2 引用明细

(同上格式)

---

## 跨关键词关系分析

> 以下模块/类同时涉及多个关键词，可能存在关联。

| # | 模块 | 类/文件 | 涉及关键词 | 说明 |
|---|------|---------|-----------|------|
| 1 | ModuleA | ClassA | keyword1, keyword2 | 同一类中包含两个关键词的属性 |
| 2 | ModuleB | ClassB.m | keyword1, keyword3 | 方法中同时引用 |
```

---

## 2. 引用明细表列定义

| 列名 | 说明 | 示例 |
|------|------|------|
| `#` | 序号 | 1, 2, 3 |
| `模块` | Framework / Pod / 目录模块名 | `BTLiveModule`, `SDWebImage` |
| `类/文件` | 类名或文件名 | `BTAnonymousManager`, `Config.plist` |
| `符号/属性` | 匹配的符号、属性名或代码片段 | `isAnonymous`, `-[Foo bar]` |
| `类型` | 符号类型枚举（见下表） | `property`, `method` |
| `来源` | 搜索来源 | `源码`, `Header`, `二进制(strings)` |
| `描述` | 位置信息或补充说明 | `File.m:123`, `libFoo.framework` |

### 类型枚举

| 类型值 | 说明 |
|--------|------|
| `class_definition` | 类定义或 `_OBJC_CLASS_$_` 符号 |
| `property` | `@property` 声明 |
| `property_encoding` | 属性类型编码 `T@"Type"` |
| `method` | 方法声明或 `-[Class method]` |
| `ivar` | 实例变量 `_OBJC_IVAR_$_` |
| `import` | `#import` / `@import` 语句 |
| `string_constant` | 字符串常量引用 |
| `commented_out` | 注释中的引用 |
| `reference` | 其他一般引用 |

### 来源枚举

| 来源值 | 说明 |
|--------|------|
| `源码` | 工程源码文件（`.h`, `.m`, `.swift` 等） |
| `Header` | Framework Headers 目录下的头文件 |
| `二进制(strings)` | Framework / 静态库二进制中通过 `strings` 提取 |

---

## 3. 跨关键词关系分析触发条件

当满足以下条件时输出关系分析表：

- **模式：** `batch` 或 `related`
- **触发：** 同一 (模块, 类/文件) 组合出现在 2 个及以上关键词的结果中
- **排序：** 按涉及关键词数量降序

### 关系分析表用途

- 识别功能模块间的耦合关系
- 评估符号下线的影响范围
- 发现同一类中多个相关符号的聚集

---

## 4. batch 模式末尾附加内容

batch 模式在所有关键词明细表之后，附加：

```markdown
## 综合关联关系

### 按模块汇总

| 模块 | 涉及关键词 | 总命中数 |
|------|-----------|----------|
| ModuleA | keyword1, keyword2 | N |
| ModuleB | keyword1 | N |

### 关联类清单

| 类 | 所属模块 | keyword1 | keyword2 | keyword3 |
|----|---------|----------|----------|----------|
| ClassA | ModuleA | 3 | 2 | 0 |
| ClassB | ModuleB | 1 | 0 | 1 |
```

---

## 5. 注意事项

- 二进制 `strings` 结果可能包含非符号噪音（普通字符串恰好匹配关键词），通过 ObjC 运行时格式校验可过滤大部分噪音
- 表格中的行号基于扫描时的文件状态
- 当结果超过 200 行时，建议分模块展示或折叠三方 SDK 部分
- `output_file` 指定时报告写入文件，对话中只展示统计汇总
- 超时跳过的二进制在统计汇总中注明，避免用户误以为该二进制无引用
