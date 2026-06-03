# 输出精简规则（rtk 风格）

> 实现：`scripts/xcb-summarize.awk`（被 `xcb-run.sh` 调用）。
> 设计参考 [rtk-ai/rtk](https://github.com/rtk-ai/rtk)：Smart Filtering / Grouping / Dedup / Failures-first。

## 为什么不直接用 xcbeautify

`xcbeautify` 是优秀的**美化**工具，但放进 agent 的 stdout 路径会**增加** token（它逐条渲染编译过程），
与"省 token"目标相悖；且其改写后的行格式会破坏精简器的模式匹配。

因此：**awk 精简器是 agent 摘要的唯一来源**（确定性、无依赖、token 收益可控）；
`xcbeautify` 仅在 `WK_XCB_PRETTY=1` 时用于生成额外的 `*.pretty.log` 人类可读日志，不进 stdout。

## 保留（对决策有价值）

| 类别 | 匹配 |
|---|---|
| 结果标记 | `** BUILD/TEST/CLEAN/ARCHIVE/INSTALL/ANALYZE SUCCEEDED/FAILED **`、`Testing failed:` |
| 编译错误 | `: error:` / `^error:` / `: fatal error:` |
| 命令失败 | `Command ... failed with ... exit code`、`The following build commands failed:` 块 |
| 链接错误 | `Undefined symbols ...` 块、`ld: ...`、`symbol(s) not found`、`linker command failed` |
| 签名错误 | `Code Sign error`、`No signing certificate`、`requires a development team`、`Provisioning profile ...` |
| 测试失败 | `Test Case ... failed`（权威计数源）、`Failing tests:` 块、测试汇总 `Executed N tests ...` |
| 编译警告 | `: warning:` / `^warning:`（**去重 + 计数**，默认最多展示 30 条） |

## 剥离（噪声）

- 编译任务行：`CompileC` / `CompileSwift` / `SwiftCompile` / `Ld` / `CodeSign` / `ProcessInfoPlistFile`
  / `CpResource` / `PhaseScriptExecution` / `WriteAuxiliaryFile` / `RegisterExecutionPolicyException` 等
- 任务详情：缩进的 `cd` / `export` / 工具绝对路径调用、环境变量 dump
- 进度/元信息：`note: Building targets ...`、`Resolving Package Graph`、`Build description signature` 等
- 重复 warning（折叠为 unique 计数）

## 摘要格式

```
=== xcodebuild summary ===
result : <结果或推断>
counts : errors=N  warnings=M(unique=K)  linker=N  signing=N  test_failures=T

-- test summary --      (有则显示)
-- errors --            (有则显示)
-- linker (errors) --
-- code signing --
-- test failures --
-- failing tests --     (来自 Failing tests/Testing failed 块，仅展示)
-- warnings (unique, showing X of K) --
```

由 `xcb-run.sh` 追加页脚：

```
----
exit code : <xcodebuild 退出码>
raw log   : <完整原始日志路径>
pretty log: <可选>
```

## 阅读建议（给 agent）

1. 先看 `result` + `counts` 判断成败与规模。
2. 失败按分区定位（errors → linker → signing → test failures）。
3. **需要更多上下文时**，对 `raw log` 文件做**针对性 grep**（如按 file:line），
   不要整体读入，避免重新填充上下文。

## 调参

| 变量 | 默认 | 作用 |
|---|---|---|
| `WK_XCB_WMAX` | 30 | warning 去重后展示上限 |
| `WK_XCB_MAXBODY` | 240 | 摘要正文总行数上限（超出截断并提示） |

## 退出码透传

`xcb-run.sh` 透传 xcodebuild 退出码（成功 0；编译失败常见 65；用法/参数错误 64/66；
多真机需用户选择 3）。agent 可据退出码快速判断。
