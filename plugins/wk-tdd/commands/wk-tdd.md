---
description: iOS/macOS TDD 工作流引导 — 强制先写测试（RED→GREEN→REFACTOR），覆盖 Swift Testing / XCTest / OCMock，内置覆盖率验证
mode: skill
skill_file: skills/wk-tdd/SKILL.md
---

# /wk-tdd

iOS/macOS 测试驱动开发引导。先写测试，再写实现，不许绕过 RED 阶段。

## 用法

```
/wk-tdd <参数>
```

## 参数格式

以 YAML 或自然语言传入，支持以下字段：

- `task` — 要实现的功能描述（必填，或直接用自然语言）
- `lang` — 语言选择（默认 `auto` 自动检测）：
  - `auto` — 根据目标文件自动选择
  - `swift` — 使用 Swift Testing 框架（`@Test` / `#expect`）
  - `objc` — 使用 XCTest + OCMock
- `target` — 被测文件或类名（可选，有助于定位上下文）
- `coverage` — 是否最终执行覆盖率验证（默认 `true`）
- `phase` — 指定从哪个阶段接入（默认 `start`）：
  - `start` — 从头开始完整 TDD 流程
  - `red` — 只写失败测试
  - `green` — 只写最小实现让测试通过
  - `refactor` — 只做重构
  - `coverage` — 只做覆盖率分析

## 使用示例

### 从零开始 TDD 一个功能

```
/wk-tdd task="实现用户登录状态管理 LoginManager"
```

### 指定语言和目标文件

```
/wk-tdd target=BTIMService.m lang=objc
```

### 只写 Swift 失败测试（RED 阶段）

```
/wk-tdd task="缓存过期检测" lang=swift phase=red
```

### 对现有代码补测试 + 覆盖率

```
/wk-tdd target=MessageSyncService.swift phase=coverage
```

### 自然语言

```
/wk-tdd 帮我用 TDD 实现一个消息去重队列，ObjC 写的
/wk-tdd 给 UserSessionManager.swift 补测试，要覆盖 token 过期场景
/wk-tdd 先帮我写 red 阶段的测试，目标是 NetworkRetryPolicy
```

## 输出

每个阶段结构化输出：

- **RED** — 完整失败测试代码 + 运行命令 + 预期失败原因
- **GREEN** — 最小实现代码 + 运行命令 + 通过确认
- **REFACTOR** — 重构建议 + 改动说明 + 测试仍绿确认
- **COVERAGE** — 覆盖率报告（文件级别，按维度：语句/分支/函数/行），未达标则给出补测方向

$ARGUMENTS
