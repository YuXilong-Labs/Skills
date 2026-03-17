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

# JSON 输出（供工具链消费）
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py --json path/to/file.m
```

## 强制规则

1. **每次 Edit/Write iOS 源码后立即运行检查** — 对变更的文件执行
2. **git commit 前必须通过检查** — 发现违规则**禁止提交**，列出所有问题
3. **退出码**：0 = 通过，1 = 发现违规
4. **检查范围**：所有变更的 `.h`/`.m`/`.mm`/`.swift`/`.c`/`.cpp` 文件

## 匹配模式

脚本使用三种匹配模式避免误判：

| 模式 | 规则 | 匹配 | 不匹配 |
|------|------|------|--------|
| `exact` | 完整 token | `match` | `matching`、`ClosedEnumSupportKnown` |
| `word_boundary` | 单词边界 | `casino`、`Casino` | `occasion` |
| `compound` | 复合标识符组件 | `payCoins`、`wx_pay`、`payMoney` | `payload`、`display`、`repay` |

**compound 核心逻辑**：关键词必须在驼峰/下划线语义边界上，纯子串放行。

## 违规处理流程

1. 列出所有违规项（文件、行号、关键词、匹配文本）
2. **禁止 git commit**
3. 修复方案：
   - 业务字段名 → 改为同义词（`money` → `coinAmount`、`price` → `cost`）
   - 自动生成代码 → 在生成脚本中添加后处理替换
   - 确为误判 → 在脚本 `COMPOUND_WHITELIST` 中加白名单

## 维护

**添加白名单**：编辑 `scripts/check_blocked_words.py` 的 `COMPOUND_WHITELIST`。

**添加关键词**：编辑 `scripts/check_blocked_words.py` 的 `BLOCKED_WORDS` 列表。
