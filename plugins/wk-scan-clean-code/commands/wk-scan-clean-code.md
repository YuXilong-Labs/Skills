---
description: 对 ObjC/Swift 工程执行代码清理审计，识别可安全删除的字段、方法、文件
mode: skill
skill_file: skills/wk-scan-clean-code/SKILL.md
---

# /wk-scan-clean-code

对 iOS/macOS Objective-C 和 Swift 工程执行代码清理审计。

## 用法

```
/wk-scan-clean-code <参数>
```

## 参数格式

以 YAML 或自然语言传入，支持以下字段：

- `target_file` — 待审计的目标文件路径（单文件审计时必填）
- `project_root` — 工程根目录，默认当前目录
- `business_scope` — 业务代码目录，默认同 project_root
- `exclude_paths` — 排除路径，默认 `Pods,Vendor,ThirdParty,Carthage,Build,DerivedData`
- `language` — `objc` / `swift` / `auto`（默认自动检测）
- `mode` — 扫描模式：
  - `model-fields` — Model 字段审计（默认）
  - `dead-code` — 死代码检测
  - `unused-files` — 无用文件检测
  - `full` — 全量扫描

## 使用示例

### Model 字段审计

```
/wk-scan-clean-code target_file=Models/UserModel.h project_root=. mode=model-fields
```

### 死代码检测

```
/wk-scan-clean-code project_root=. business_scope=Sources mode=dead-code
```

### 无用文件检测

```
/wk-scan-clean-code project_root=. mode=unused-files exclude_paths=Pods,Vendor,Tests
```

### 全量扫描

```
/wk-scan-clean-code project_root=. mode=full
```

### 自然语言

```
/wk-scan-clean-code 帮我检查 UserModel.h 里哪些字段没有被使用
/wk-scan-clean-code 扫描 Sources 目录下的死代码
/wk-scan-clean-code 找出工程里没用的文件
```

## 输出

结构化 Markdown 报告，包含：
- 审计概要（目标、范围、模式）
- 统计汇总（各分类数量）
- 可清理项明细（附证据链）
- 需谨慎确认项明细
- 活跃使用项列表

$ARGUMENTS
