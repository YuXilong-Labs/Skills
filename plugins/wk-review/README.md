# wk-review

本地代码修改 Review 工具 — 基于 git diff，以资深开发视角审查代码变更。

## 审查维度

| 维度 | 关注点 |
|------|--------|
| **逻辑 Bug** | 条件判断、边界值、流程控制、状态管理 |
| **影响分析** | 行为变更、副作用、接口兼容性、依赖关系 |
| **Crash 风险** | 空值访问、数组越界、类型强转、线程安全 |
| **内存泄漏** | 循环引用、闭包捕获、通知/KVO 未移除、定时器 |
| **性能问题** | 主线程阻塞、重复计算、大数据拷贝、内存峰值 |
| **资源管理** | 文件句柄、数据库连接、定时器、音视频 session |

## 特点

- 支持 Swift 和 Objective-C
- 所有结论附带准确行号和代码证据
- 四级严重程度分级（CRITICAL / HIGH / MEDIUM / LOW）
- 只读操作，不自动修改代码
- 多种 diff 范围支持（staged / unstaged / branch / commit）

## 使用

```bash
# 审查所有本地修改（默认）
/wk-review

# 仅审查已暂存修改
/wk-review scope=staged

# 审查当前分支的所有修改
/wk-review scope=branch

# 聚焦特定领域
/wk-review focus=crash,memory

# 自然语言
/wk-review 帮我 review 下本地修改
/wk-review 看看有没有内存泄漏
```

## 输出

结构化 Markdown 报告，包含：
- 修改概要（文件列表、变更统计）
- 问题列表（按严重程度分级，附行号、代码证据、修复建议）
- 影响分析（本次修改对原有逻辑的影响）
- 总结与建议
