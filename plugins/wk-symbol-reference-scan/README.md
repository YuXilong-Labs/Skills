# wk-symbol-reference-scan

iOS 工程全局符号引用扫描工具 — 覆盖源码、Framework Headers、二进制 strings，输出结构化报告。

## 功能

| 模式 | 说明 |
|------|------|
| 单关键词扫描 | 快速确认某个符号在工程中的使用情况 |
| `batch` | 多关键词逐一扫描，附加综合关联关系分析 |
| `related` | 自动扩展相关符号变体后批量扫描 |

## 特点

- 三条并行搜索路径：源码 Grep、Framework Headers、二进制 strings
- ObjC 运行时符号分类（class/property/method/ivar 等）
- 业务模块 vs 三方 SDK 自动分类
- 四元组去重（模块, 类, 符号名, 符号类型）
- 只读操作，不修改任何文件
- strings 超时保护（30s/次）

## 使用

```bash
# 单关键词扫描
/wk-symbol-reference-scan keywords=FeatureX project_root=.

# 批量扫描
/wk-symbol-reference-scan keywords=FeatureX,FeatureY mode=batch output_file=ref.md

# 关联扫描
/wk-symbol-reference-scan keywords=FeatureX mode=related include_third_party=true

# 自然语言
/wk-symbol-reference-scan 帮我查一下 FeatureX 在工程里哪些地方用到了，包括二进制 framework
```
