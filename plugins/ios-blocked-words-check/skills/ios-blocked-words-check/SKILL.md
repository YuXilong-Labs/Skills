---
name: ios-blocked-words-check
description: >
  iOS App Store 审核合规禁止关键词检查工具。自动检测 iOS 源码(.h/.m/.mm/.swift)中的
  敏感词（赌博、支付、金融等 App Store 审核高危词），防止代码提交后被拒审。
  TRIGGER: 当编写、修改、生成任何 iOS 源码文件(.h/.m/.mm/.swift/.c/.cpp)时自动触发。
  包括但不限于：(1) 新建 iOS 代码文件 (2) 修改现有 iOS 代码 (3) protobuf/代码生成器输出
  (4) git 提交前检查 (5) 用户提及"敏感词""关键词检查""blocked words"时。
  必须在 git commit 之前运行检查，发现违规则禁止提交。
---

# iOS 禁止关键词检查

## 检查命令

```bash
# 检查指定文件
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py path/to/file.m

# 检查 git staged 文件（提交前）
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py --staged

# 检查目录下所有 iOS 文件
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py --all ./SomeDir

# 批量汇总（跳过注释）
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py \
  --all ./SomeDir --skip-comments --summary

# 批量汇总 + proto 溯源
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py \
  --all ./SomeDir --skip-comments --summary --trace-proto <proto_root>

# JSON 输出（供工具链消费）
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py --json path/to/file.m
```

## 强制规则

1. **每次 Edit/Write iOS 源码后立即运行检查** — 对变更的文件执行
2. **git commit 前必须通过检查** — 发现违规则**禁止提交**，列出所有问题
3. **退出码**：0 = 通过，1 = 发现违规
4. **检查范围**：所有变更的 `.h`/`.m`/`.mm`/`.swift`/`.c`/`.cpp` 文件

## 参数说明

| 参数 | 用途 |
|------|------|
| `--all <dir>` | 递归检查目录下所有 iOS 源码文件 |
| `--staged` | 检查 git staged 文件 |
| `--skip-comments` | 跳过注释行（`//`、`/*`、`*` 开头），只检查代码/字段 |
| `--summary` | 输出汇总表格格式（按敏感词聚合） |
| `--trace-proto <dir>` | 对 protobuf 生成文件自动追溯源 proto 并定位字段行号 |
| `--json` | JSON 格式输出 |

## 匹配模式

脚本使用三种匹配模式避免误判：

| 模式 | 规则 | 匹配 | 不匹配 |
|------|------|------|--------|
| `exact` | 完整 token | `match` | `matching`、`ClosedEnumSupportKnown` |
| `word_boundary` | 单词边界 | `casino`、`Casino` | `occasion` |
| `compound` | 复合标识符组件 | `payCoins`、`wx_pay`、`payMoney` | `payload`、`display`、`repay` |

**compound 核心逻辑**：关键词必须在驼峰/下划线语义边界上，纯子串放行。

## 违规处理流程（单文件）

1. 列出所有违规项（文件、行号、关键词、匹配文本）
2. **禁止 git commit**
3. 修复方案：
   - 业务字段名 → 改为同义词（敏感词 → 同义替换词，如 `coinAmount`、`cost`）
   - 自动生成代码 → 在生成脚本中添加后处理替换
   - 确为误判 → 在脚本 `COMPOUND_WHITELIST` 中加白名单

## 批量检查流程（subagent 模式）

**适用场景**：代码生成器执行后 / 批量修改 iOS 文件后 / git commit 前的整体检查

### 工作流

1. **主 agent 派发 subagent 执行批量检查**：
   ```
   使用 Agent 工具（subagent_type: general-purpose）执行：
   python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py \
     --all <目录> --skip-comments --summary [--trace-proto <proto_root>]
   ```

2. **subagent 返回汇总结果**（示例）：
   ```
   敏感词检查汇总：3 个敏感词，共 14 处命中（已忽略注释）

   | 敏感词 | 命中数 | 涉及文件数 | 源 proto 文件 | proto 行号 | 字段定义 |
   |--------|--------|-----------|--------------|-----------|---------|
   | <词A>  | 6      | 2         | biz/xxx.proto | L26 | int64 <词A> = 1; |
   | <词B>  | 4      | 3         | biz/xxx.proto | L54 | int64 <词B> = 7; |
   | <词C>  | 4      | 1         | biz/yyy.proto | L30 | string <词C>_sticker = 16; |
   ```

3. **主 agent 使用 AskUserQuestion 给用户选项**：
   - **忽略并继续当前工作流** — 本次不处理敏感词，继续执行后续任务
   - **停止当前工作流** — 中断当前任务，优先处理敏感词问题

### 选项处理逻辑

- **用户选择「忽略并继续」**：记录日志，继续执行原工作流
- **用户选择「停止」**：中断工作流，输出修复建议（同义词替换 / proto 字段重命名 / 白名单）

### 典型使用示例

```
# protobuf 生成后的批量检查
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py \
  --all BTProtobufMessages/Classes/PB \
  --skip-comments --summary \
  --trace-proto proto/mqtt-idl
```

## 维护

**添加白名单**：编辑 `scripts/check_blocked_words.py` 的 `COMPOUND_WHITELIST`。

**添加关键词**：编辑 `scripts/check_blocked_words.py` 的 `BLOCKED_WORDS` 列表。
