---
description: iOS Crash 闭环排查 — 根因定位、稳定复现、修复落地、回归验证
mode: skill
skill_file: skills/wk-crash-repro-fix/SKILL.md
---

# /wk-crash-repro-fix

iOS 崩溃问题端到端闭环处理：根因定位 → 稳定复现 → 修复落地 → 回归验证。

## 用法

```
/wk-crash-repro-fix <参数>
```

## 输入参数

以 YAML 或自然语言传入，支持以下字段：

- `crash_type` — 崩溃类型：`EXC_BAD_ACCESS` / `SIGABRT` / 断言 / 其他
- `stack` — 关键堆栈信息（符号化后的崩溃栈或关键行号）
- `scenario` — 触发场景描述（网络、前后台切换、并发、定时器等）
- `scheme` — Xcode scheme 名称
- `destination` — 目标设备/模拟器 ID

## 使用示例

### 提供崩溃栈分析

```
/wk-crash-repro-fix crash_type=EXC_BAD_ACCESS stack="BTDNSManager dealloc thread:bg"
```

### 指定场景复现

```
/wk-crash-repro-fix scenario=前后台切换时DNS定时器野指针 scheme=BTNetwork-Example
```

### 自然语言

```
/wk-crash-repro-fix 帮我分析这个 crash，EXC_BAD_ACCESS 在 BTDNSManager dealloc 时触发
/wk-crash-repro-fix 先写一个稳定复现用例，定时器和 dealloc 竞态
/wk-crash-repro-fix 开始修复并验证，跑高压回归
```

## 输出

结构化报告，包含：
- 根因结论（一句话 + 证据文件行号）
- 复现方案（P0/P1 覆盖范围与参数）
- 修复说明（改动点、线程语义变化、安全性论证）
- 验证结果（通过/失败、压测参数、耗时）
- 风险评审（业务影响、残余风险）
- 下一步建议

$ARGUMENTS
