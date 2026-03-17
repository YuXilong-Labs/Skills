# ios-blocked-words-check

iOS App Store 审核合规禁止关键词检查工具。

## 功能

自动检测 iOS 源码（`.h`/`.m`/`.mm`/`.swift`/`.c`/`.cpp`）中的 App Store 审核高危词，防止含敏感词的代码被提交后导致审核被拒。

## 覆盖关键词类别

| 类别 | 示例 |
|------|------|
| 赌博相关 | casino, jackpot, gamble, poker, lottery, roulette... |
| 支付/金融品牌 | PayPal, Stripe, Alipay, Paytm, Adyen... |
| 金钱/货币 | money, price, cash, diamond, wallet, credits... |
| 游戏/博彩 | game, bet, win, lose, prize, match... |
| 复合标识符 | chat\_price, game\_id, wx\_pay, prize\_pool... |

## 三种匹配模式（智能防误判）

| 模式 | 说明 | 匹配 | 不匹配 |
|------|------|------|--------|
| `compound` | 复合标识符组件 | `payCoins`、`wx_pay`、`payMoney` | `payload`、`display`、`repay` |
| `exact` | 完整 token 匹配 | 独立的 `match`、`lose` | `matching`、`ClosedEnumSupportKnown` |
| `word_boundary` | 单词边界匹配 | `casino`、`Casino` | 不会误判 |

**compound 核心逻辑**：关键词必须出现在标识符的驼峰/下划线语义边界上（如 `payCoins` 中的 `pay`），纯子串（如 `payload` 中的 `pay`）自动放行。内置白名单覆盖 `payload`、`display`、`window`、`cache`、`beta`、`broadcast` 等常见误判项。

## 使用

### 命令行

```bash
# 检查指定文件
python3 scripts/check_blocked_words.py path/to/file.m

# 检查 git staged 文件
python3 scripts/check_blocked_words.py --staged

# 检查目录下所有 iOS 文件
python3 scripts/check_blocked_words.py --all ./SomeDir

# JSON 格式输出
python3 scripts/check_blocked_words.py --json path/to/file.m
```

### Claude Code Slash 命令

```
/ios-blocked-words-check file=Classes/PB/SendGift.pbobjc.m
/ios-blocked-words-check --staged
/ios-blocked-words-check --all Classes/
```

### 自然语言

```
/ios-blocked-words-check 帮我检查 SendGift.pbobjc.m 里有没有敏感词
```

## 输出示例

```
❌ 发现 3 处禁止关键词命中

📄 Classes/PB/SendGift.pbobjc.h
  L 161 | 关键词 'money' → 匹配 'money'
       | @property(nonatomic, readwrite) int64_t money;
  L 286 | 关键词 'price' → 匹配 'price'
       | @property(nonatomic, readwrite) int64_t price;

📄 Classes/PB/SendGift.pbobjc.m
  L 347 | 关键词 'money' → 匹配 'money'
       | @dynamic money;
```

## 自定义

### 添加白名单

编辑 `scripts/check_blocked_words.py` 中的 `COMPOUND_WHITELIST`：

```python
COMPOUND_WHITELIST = {
    "payload", "window", "cache", "beta",
    "your_new_word",  # 新增
}
```

### 添加关键词

编辑 `BLOCKED_WORDS` 列表：

```python
{"word": "newword", "mode": "compound"},      # 短词，可组合
{"word": "newword", "mode": "exact"},          # 精确匹配
{"word": "newword", "mode": "word_boundary"},  # 长词，不误判
```

## 配套 Hook

配合 [ios-blocked-words-hook](../ios-blocked-words-hook/) 可实现 Edit/Write iOS 文件后自动触发检查。
