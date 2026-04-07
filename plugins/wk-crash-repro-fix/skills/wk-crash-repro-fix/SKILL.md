---
name: wk-crash-repro-fix
description: 用于 iOS 崩溃问题的端到端闭环处理：从 crash 堆栈定位根因、设计并实现本地稳定复现用例、落地修复、到回归验证与业务影响评审。用户提出"帮我分析 crash""先写稳定复现""开始修复并验证""加压回归并 review 风险"等请求时使用。
---

# iOS Crash Repro Fix Playbook

## 目标

将一次崩溃处理沉淀为可复用工程流程，确保输出同时包含：
1. 可证据化的根因分析
2. 可重复执行的复现用例
3. 最小破坏面的修复方案
4. 可量化的回归验证结论

## 输入要求

先收集并确认以下信息，不完整时先补齐再改代码：
1. 崩溃类型与关键线程：`EXC_BAD_ACCESS` / `SIGABRT` / 断言等。
2. 关键堆栈与符号化行号：至少包含 1 条触发链路。
3. 触发场景：网络、前后台切换、并发、定时器、对象释放等。
4. 当前代码状态：是否已存在复现测试、是否已有临时注入。
5. 验证环境：`scheme`、目标设备/模拟器、是否允许 DEBUG 注入。

## 执行流程

### 1. 定位根因（先证据后结论）

1. 读取崩溃栈对应源码，明确"谁释放了谁、在哪个线程、是否并发访问"。
2. 标注高危对象：`NSTimer`、`delegate`、共享状态、`dispatch_sync` 互等链。
3. 给出根因假设并写明证据文件和行号。
4. 若证据不足，先补日志/断言/调试注入，再继续分析。

### 2. 设计稳定复现（先 P0，再 P1）

1. 优先做 P0：直接命中根因的最小复现路径（少依赖外部网络与环境）。
2. 再做 P1：贴近线上真实调用栈的链路复现。
3. 复现用 `XCTest` + `DEBUG` 注入放大竞态窗口。
4. 用环境变量或编译宏 gating，默认跳过高危 crash 用例。

### 3. 实现复现用例（可持续运行）

1. 在测试目标新增单测类，命名清晰表达"手动复现 + 触发机制"。
2. 用可调参数控制压测规模：`ROUNDS`、`WORKERS`、`TIMEOUT`。
3. 强制收敛执行线程模型（如主线程 runloop 驱动、后台并发 burst）。
4. 未修复版本目标：高概率复现崩溃或明显异常行为。
5. 已修复版本目标：同参数下稳定通过。

### 4. 实施修复（最小改动、避免新死锁）

1. P0 修复先消除直接内存安全问题：线程亲和、生命周期、并发读写保护。
2. P1 修复再统一上层调用语义：串行队列、状态机、可重入约束。
3. 警惕把"崩溃"变成"卡死"：
   - 慎用跨线程 `dispatch_sync`。
   - 明确主线程与业务串行队列的调用方向，避免互等。
4. 保持公开 API 不变；调试注入仅放 `#ifdef DEBUG` 私有实现。

### 5. 回归验证（功能 + 稳定性 + 风险评审）

1. 跑复现用例基础档与高压档至少各一轮。
2. 记录结果：是否崩溃、是否卡住、耗时、线程告警。
3. 评审业务影响：
   - 原调用是否变为阻塞。
   - 定时器/网络请求/前后台行为是否改变。
   - 是否引入新的优先级反转或死锁风险。
4. 明确结论：`通过 / 不通过 / 有条件通过`。

## 常用命令模板

```bash
# 仅跑指定复现用例
xcodebuild \
  -workspace Example/BTNetwork.xcworkspace \
  -scheme BTNetwork-Example \
  -destination 'id=<DESTINATION_ID>' \
  -only-testing:BTNetwork_Tests/BTDNSCrashReproTests/test_manualCrashRepro_DisableDNS_TimerRace \
  test
```

```bash
# 高压参数示例（通过编译宏覆盖默认值）
xcodebuild \
  -workspace Example/BTNetwork.xcworkspace \
  -scheme BTNetwork-Example \
  -destination 'id=<DESTINATION_ID>' \
  "GCC_PREPROCESSOR_DEFINITIONS=$(inherited) BT_FORCE_RUN_CRASH_REPRO=1 BT_REPRO_DEFAULT_ROUNDS=10000 BT_REPRO_DEFAULT_WORKERS=120 BT_REPRO_DEFAULT_TIMEOUT=240" \
  -only-testing:BTNetwork_Tests/BTDNSCrashReproTests/test_manualCrashRepro_DisableDNS_TimerRace \
  test
```

## 输出模板

按以下结构输出结果：
1. 根因结论：一句话 + 证据文件行号。
2. 复现方案：P0/P1 覆盖范围与参数。
3. 修复说明：改动点、线程语义变化、为何安全。
4. 验证结果：通过/失败、压测参数、耗时、异常。
5. 风险评审：是否影响旧业务逻辑，残余风险是什么。
6. 下一步建议：继续加压、补充测试、是否可合入。

## 质量门禁

在宣布"修复完成"前，必须同时满足：
1. 复现用例在修复前后行为差异明确（前失败/后通过）。
2. 至少一轮高压回归可收敛结束，不出现无限等待。
3. 已给出业务影响评审，不省略线程/阻塞风险说明。
