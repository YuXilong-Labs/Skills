---
description: iOS 工程全局符号引用扫描 — 覆盖源码、Framework 二进制、Headers，输出结构化报告
mode: skill
skill_file: skills/symbol-reference-scan/SKILL.md
---

# /symbol-reference-scan

在 iOS 工程中全面扫描指定符号的引用位置，覆盖源码、Framework Headers、二进制 strings 三条搜索路径，输出结构化 Markdown 表格报告。

## 用法

```
/symbol-reference-scan <参数>
```

## 参数格式

以 YAML 或自然语言传入，支持以下字段：

- `keywords` — 待搜索关键词，逗号分隔（必填）
- `project_root` — 工程根目录，默认当前目录
- `scope` — 搜索范围：`source_only` / `binary_only` / `all`（默认 `all`）
- `exclude_paths` — 排除路径，默认 `Build,DerivedData,.git`
- `include_third_party` — 是否包含三方 SDK 结果，默认 `false`
- `output_file` — 报告输出文件路径（不指定则直接输出）
- `mode` — 扫描模式：
  - `single` — 单关键词扫描（默认）
  - `batch` — 批量扫描，附加关联关系分析
  - `related` — 自动扩展相关符号后扫描
- `case_sensitive` — 是否区分大小写，默认 `false`

## 使用示例

### 单关键词扫描

```
/symbol-reference-scan keywords=FeatureX project_root=.
```

### 批量扫描

```
/symbol-reference-scan keywords=FeatureX,FeatureY,FeatureZ mode=batch output_file=symbol_ref.md
```

### 关联扫描（自动扩展）

```
/symbol-reference-scan keywords=FeatureX mode=related include_third_party=true
```

### 仅源码搜索

```
/symbol-reference-scan keywords=BTLiveManager scope=source_only
```

### 自然语言

```
/symbol-reference-scan 帮我查一下 FeatureX 这个符号在工程里哪些地方用到了，包括二进制 framework
/symbol-reference-scan 批量扫描 FeatureX 和 FeatureY 的引用，输出到文件
/symbol-reference-scan 扫描 FeatureX 相关的所有符号变体
```

## 输出

结构化 Markdown 报告，包含：
- 扫描概要（关键词、范围、模式）
- 统计汇总（各来源命中数、模块分布）
- 每关键词引用明细表（模块、类、符号、类型、来源）
- 跨关键词关系分析表（batch/related 模式）

$ARGUMENTS
