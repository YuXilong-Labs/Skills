# xcresult / 覆盖率结构化摘要（xcb result / xcb cov）

> 实现：`scripts/xcb-result.sh`（经 `xcb-run.sh` 子命令分发，依赖 jq + Xcode 16+ 的
> `xcresulttool get test-results` 新接口）。

## 为什么需要它（实测数据）

| 裸命令 | 原始输出 | 摘要后 |
|---|---|---|
| `xcresulttool get test-results summary`（286 用例全过） | ~983 字符 / 41 行 | ~15 行 |
| `xcresulttool get test-results tests` | **~155K 字符（~39K token）** | ~94 token（省 99%） |
| `xccov view --report --json` | 大型工程数千行（逐文件逐函数） | 总览 + 最差 N 文件 |

裸跑的三个坑（手工 `summary 2>/dev/null | head -n 80` 同样命中）：

1. **`head` 截断关键字段** — JSON 顶层键按字母序输出，`devicesAndConfigurations`
   排最前；多设备/多 configuration 时 `result` / `testFailures` / `failedTests`
   全在 80 行之外，agent 拿到不完整 JSON 还以为没失败。
2. **`2>/dev/null` 吞错误** — 路径错/bundle 损坏时输出为空，无法区分"没结果"和"全过"。
3. **失败时膨胀** — `testFailures[].failureText` 带完整断言 dump，几个失败就上千行。

## 为什么计数以 xcresult 为权威

`xcb-summarize.awk` 的文本正则面向 xcodebuild 输出流，XCTest（`Test Case ... failed`）
与 Swift Testing（前缀符号随运行方式变化：xcodebuild 下是私有区符号 `􀢄`，
`swift test` 终端下是 `✘`）格式各异、易随 Xcode 版本漂移；
`xcresulttool` 的 JSON 对两个框架统一计数（`passedTests`/`failedTests`/`skippedTests`/
`expectedFailures`），是唯一稳定权威源。因此 test 类动作跑完自动追加
`=== xcresult summary ===` 分区，**成败判断优先看该分区**。

## 自动注入与定位

- `test` / `test-without-building`（仅 xcodebuild 路径）：未显式传 `-resultBundlePath`
  时自动注入 `$TMPDIR/wk-xcodebuild/xcb-<ts>-<pid>.xcresult`；用户已传则尊重其路径，
  仅用于事后摘要。`build-for-testing` 不产出测试结果，不注入。
- 测试根本没跑起来（如 scheme 错误）时 bundle 是空壳（`result: unknown`），
  分区自动抑制，不添噪声。
- `xcb result` / `xcb cov` 缺省自动定位最新 xcresult：包装器落盘目录优先，
  其次 `~/Library/Developer/Xcode/DerivedData/*/Logs/Test/`。
- `WK_XCB_NO_XCRESULT=1` 关闭注入与分区。

## 输出格式

```
=== xcresult summary ===
bundle  : <xcresult 路径>
result  : Passed | Failed
counts  : total=4 passed=2 failed=2 skipped=0 expected_failures=0
device  : My Mac (macOS 26.5.1)
duration: 20.2s

-- failures --                  (failed>0 时)
✘ <testName>  [<targetName>]
    <failureText 首行>

-- failed cases (2 of 4) --     (仅 xcb result --tests；含 file:line)
✘ <testName> <耗时>
    <File.swift:line>: <失败信息>
```

```
=== coverage summary ===        (xcb cov；test 时需 -enableCodeCoverage YES)
overall : 92.3%  (12/13 lines)
-- targets --
92.3%   TestPkgTests
-- lowest files (top 10) --     (WK_XCB_COV_WORST 调条数)
75%     3/4     Calc.swift
```

页脚与 build/test 摘要同构：token 收益 + raw json 路径（需要全量 JSON 时按需 jq/grep，
不要整体读入）。统计与 `xcb-gain` 共用同一 `stats.jsonl`（action 为 `result`/`cov`）。

## Hook 改写规则

`xcb-guard.sh` 把裸 `(xcrun) xcresulttool get test-results summary|tests` 静默改写为
`xcb result [--tests]`（allow + updatedInput），`--path` 等后续参数原样保留
（包装器忽略未知 flag，兼容 `--compact` 等残留）。**改写失败时放行而非 deny**——
与 xcodebuild 策略不同：xcresulttool 是只读查询、跑得快，宁可放行不误伤。
其余 xcresulttool 子命令（`get log` / `get build-results` / `export` 等）不拦截。

## 退出码

`xcb result` / `xcb cov`：摘要成功为 0（**即使测试有失败**——成败看 `result` 字段）；
用法/环境错误 64；xcresult 读取/解析失败 65（如 bundle 不存在、无覆盖率数据，
错误信息含可执行的修复指引）。
