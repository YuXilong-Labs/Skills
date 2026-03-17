# wk-scan-clean-code

代码清理审计工具 — 识别 ObjC/Swift 工程中可安全删除的字段、方法、文件。

## 功能

| 模式 | 说明 |
|------|------|
| `model-fields` | Model 字段审计 — 逐字段检查是否仍被业务代码使用 |
| `dead-code` | 死代码检测 — 识别无入口方法、废弃页面、断裂调用链 |
| `unused-files` | 无用文件检测 — 找出未被引用的源文件和资源文件 |
| `full` | 全量扫描 — 综合执行以上三种检测 |

## 特点

- 支持 Objective-C 和 Swift
- 所有结论附带完整证据链（搜索 pattern + 匹配结果）
- 三级分类：可清理（高/中置信度）、需谨慎确认、活跃使用
- ObjC 动态特性感知（KVC、@selector、JSON 映射框架等）
- 只读操作，不自动修改代码

## 使用

```bash
# Model 字段审计
/wk-scan-clean-code target_file=Models/UserModel.h mode=model-fields

# 死代码检测
/wk-scan-clean-code project_root=. mode=dead-code

# 无用文件检测
/wk-scan-clean-code project_root=. mode=unused-files

# 全量扫描
/wk-scan-clean-code project_root=. mode=full

# 自然语言
/wk-scan-clean-code 帮我检查 UserModel.h 里哪些字段没用了
```

## 输出

结构化 Markdown 报告，包含：
- 审计概要（目标、范围、模式）
- 统计汇总（各分类数量）
- 可清理项明细（附证据链）
- 需谨慎确认项明细
- 活跃使用项列表
