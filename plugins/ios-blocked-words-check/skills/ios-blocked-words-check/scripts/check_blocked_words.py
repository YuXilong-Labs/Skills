#!/usr/bin/env python3
# Created by yuxilong on 2026/03/17
#
# iOS 禁止关键词检查器
# 支持三种匹配模式：exact（精确）、word_boundary（单词边界）、compound（复合词）
# 用法:
#   python3 check_blocked_words.py [file1 file2 ...]  # 检查指定文件
#   python3 check_blocked_words.py --staged            # 检查 git staged 文件
#   python3 check_blocked_words.py --all               # 检查所有 iOS 源码文件

import re
import sys
import os
import subprocess
import json
from pathlib import Path

# iOS 源码文件扩展名
IOS_EXTENSIONS = {'.h', '.m', '.mm', '.swift', '.c', '.cpp', '.cc'}

# ── 关键词规则定义 ──────────────────────────────────────────────
# mode:
#   "exact"          - 精确匹配完整 token（变量名/字段名级别），如 money 只匹配 money，
#                      不匹配 moneyFormatter 等复合词
#   "word_boundary"  - 单词边界匹配，如 casino 匹配 Casino/CASINO，不匹配 occasion
#   "compound"       - 复合词匹配，关键词可作为复合标识符的一部分出现，
#                      如 pay 匹配 payCoins/wx_pay/payMoney，但不匹配 payload/repay/display
#
# 设计原则：
# - 多词短语（"real money"、"slot machines"）→ word_boundary（出现即违规）
# - 含下划线的复合标识符（chat_price、game_id）→ exact（精确匹配该标识符）
# - 短且高频的单词（pay、win、game）→ compound（作为复合词前缀/组件出现才违规）
# - 品牌/专有名词（PayPal、Stripe）→ word_boundary（出现即违规）
# - 长且含义明确的词（casino、jackpot、gambling）→ word_boundary（不易误判）

BLOCKED_WORDS = [
    # ── 明确违规词（出现即违规，不会误判）──
    {"word": "casino",           "mode": "word_boundary"},
    {"word": "jackpot",          "mode": "word_boundary"},
    {"word": "gamble",           "mode": "word_boundary"},
    {"word": "gambling",         "mode": "word_boundary"},
    {"word": "wager",            "mode": "word_boundary"},
    {"word": "roulette",         "mode": "word_boundary"},
    {"word": "blackjack",        "mode": "word_boundary"},
    {"word": "bingo",            "mode": "word_boundary"},
    {"word": "lottery",          "mode": "word_boundary"},
    {"word": "raffle",           "mode": "word_boundary"},
    {"word": "poker",            "mode": "word_boundary"},
    {"word": "real money",       "mode": "word_boundary"},
    {"word": "real cash",        "mode": "word_boundary"},
    {"word": "casino games",     "mode": "word_boundary"},
    {"word": "slot machines",    "mode": "word_boundary"},
    {"word": "virtual currency", "mode": "word_boundary"},
    {"word": "loot box",         "mode": "word_boundary"},
    {"word": "in-app purchase",  "mode": "word_boundary"},

    # ── 支付/金融品牌（出现即违规）──
    {"word": "paypal",           "mode": "word_boundary"},
    {"word": "alipay",           "mode": "word_boundary"},
    {"word": "stripe",           "mode": "word_boundary"},
    {"word": "adyen",            "mode": "word_boundary"},
    {"word": "razorpay",         "mode": "word_boundary"},
    {"word": "paytm",            "mode": "word_boundary"},

    # ── 短词（compound 模式：作为复合标识符的组件才违规）──
    # pay: payCoins ✓违规, payMoney ✓违规, wx_pay ✓违规
    #      payload ✗放行, repay ✗放行, display ✗放行
    {"word": "pay",              "mode": "compound"},
    # win: winCoin ✓违规, bigwin ✓违规
    #      window ✗放行, darwin ✗放行, winner（需要单独处理）
    {"word": "win",              "mode": "compound"},
    # game: gameId ✓违规, game_list ✓违规
    #       gamePad（系统 API）→ 加白名单
    {"word": "game",             "mode": "compound"},
    # money: moneyAmount ✓违规
    #        money 独立出现也违规
    {"word": "money",            "mode": "compound"},
    # price: priceLabel ✓违规
    #        price 独立出现也违规
    {"word": "price",            "mode": "compound"},
    # prize: prizePool ✓违规
    {"word": "prize",            "mode": "compound"},
    # bet: betAmount ✓违规
    #      beta ✗放行, alphabet ✗放行
    {"word": "bet",              "mode": "compound"},
    # cash: cashOut ✓违规
    #       cache ✗放行, broadcast ✗放行
    {"word": "cash",             "mode": "compound"},
    # bank: bankId ✓违规
    #       bankrupt ✗放行 → 不在复合词模式误判范围
    {"word": "bank",             "mode": "compound"},
    # lose: 作为复合词不常见，用 exact 即可
    {"word": "diamond",          "mode": "compound"},
    {"word": "wallet",           "mode": "compound"},
    {"word": "stake",            "mode": "compound"},

    # ── 精确匹配标识符（完整 token 匹配）──
    {"word": "lose",             "mode": "exact"},
    {"word": "match",            "mode": "exact"},
    {"word": "credits",          "mode": "exact"},
    {"word": "exchange",         "mode": "exact"},
    {"word": "anonymity",        "mode": "exact"},
    {"word": "mystery_man",      "mode": "exact"},
    {"word": "slotgame",         "mode": "exact"},

    # ── 精确匹配的复合标识符 ──
    {"word": "chat_price",       "mode": "exact"},
    {"word": "chat_money",       "mode": "exact"},
    {"word": "chatprice",        "mode": "exact"},
    {"word": "chatmoney",        "mode": "exact"},
    {"word": "video_price",      "mode": "exact"},
    {"word": "photo_price",      "mode": "exact"},
    {"word": "bigwin",           "mode": "exact"},
    {"word": "big_win",          "mode": "exact"},
    {"word": "prize_pool",       "mode": "exact"},
    {"word": "win_coin",         "mode": "exact"},
    {"word": "grand_prize",      "mode": "exact"},
    {"word": "luck_pool",        "mode": "exact"},
    {"word": "bank_id",          "mode": "exact"},
    {"word": "wx_pay",           "mode": "exact"},
    {"word": "web_pay",          "mode": "exact"},
    {"word": "pay_type",         "mode": "exact"},
    {"word": "game_id",          "mode": "exact"},
    {"word": "game_icon",        "mode": "exact"},
    {"word": "game_list",        "mode": "exact"},
    {"word": "anonymity_avatar", "mode": "exact"},
]

# ── compound 模式白名单 ──────────────────────────────────────────
# 这些词虽然包含 blocked word 作为前缀/后缀，但属于合法用途
COMPOUND_WHITELIST = {
    # pay 的合法用途
    "payload", "payloadmessage", "btpayloadmessage", "btpayloaddecoder",
    "btpayloadroot", "decodedpayload", "btdecodedpayload",
    "repay", "display", "displayed", "displaying",
    # win 的合法用途
    "window", "windows", "darwin", "uiwindow", "nswindow",
    "winding", "rewind", "nswindowcontroller",
    # game 的合法用途
    "gamepad", "gamecontroller", "gkgame",
    # bet 的合法用途
    "beta", "alphabet", "alphabetical", "between",
    # cash 的合法用途
    "cache", "cached", "caching", "nscache", "nsurlcache",
    "broadcast", "broadcasting",
    # bank 的合法用途
    "bankrupt", "bankruptcy",
    # match 的合法用途（exact 模式下不会匹配这些，但以防万一）
    "matching", "matched", "matcher", "nspredicate",
    # stake 的合法用途
    "mistake", "mistaken",
    # price 的合法用途（无常见误判）
    # money 的合法用途（无常见误判）
    # diamond 的合法用途（无常见误判）
    # wallet 的合法用途（无常见误判）
    # exchange 的合法用途
    "nsnotificationcenter", "uiresponder",
    # prize 的合法用途（无常见误判）
    # credits 的合法用途（无常见误判）
    # lose 的合法用途
    "close", "closed", "closing", "closedenumsupportknown",
    "enclose", "enclosed",
}


def build_pattern(word: str, mode: str) -> re.Pattern:
    """根据匹配模式构建正则表达式"""
    escaped = re.escape(word)

    if mode == "exact":
        # 精确匹配完整 token：前后必须是非标识符字符
        # 标识符字符 = [a-zA-Z0-9_]
        return re.compile(r'(?<![a-zA-Z0-9_])' + escaped + r'(?![a-zA-Z0-9_])', re.IGNORECASE)

    elif mode == "word_boundary":
        # 单词边界匹配（适用于多词短语和品牌名）
        return re.compile(r'\b' + escaped + r'\b', re.IGNORECASE)

    elif mode == "compound":
        # 复合词匹配：关键词可作为标识符的组件出现
        # 匹配场景：
        #   1. 独立出现: money (前后非标识符字符)
        #   2. 驼峰前缀: payCoins, moneyAmount (后跟大写字母)
        #   3. 驼峰后缀: chatMoney, bigWin (前面是小写字母 + 关键词首字母大写)
        #   4. 下划线连接: pay_type, chat_money (前后有下划线)
        #   5. 全大写: PAY_TYPE, GAME_ID
        #
        # 用负向前瞻/后顾排除纯粹的子串（如 payload 中的 pay）
        # 策略：匹配包含关键词的完整标识符，然后检查白名单

        # 匹配包含该词的完整标识符
        return re.compile(
            r'[a-zA-Z_]*' + escaped + r'[a-zA-Z_]*',
            re.IGNORECASE
        )

    raise ValueError(f"Unknown mode: {mode}")


def is_whitelisted(full_token: str) -> bool:
    """检查完整 token 是否在白名单中"""
    return full_token.lower() in COMPOUND_WHITELIST


def is_compound_match(full_token: str, keyword: str) -> bool:
    """判断 compound 模式下，token 是否真正包含关键词作为语义组件

    规则：
    - 关键词本身独立出现 → 违规
    - 关键词作为驼峰组件（payCoins, chatMoney）→ 违规
    - 关键词作为下划线组件（pay_type, chat_money）→ 违规
    - 关键词作为全大写组件（PAY_TYPE）→ 违规
    - 关键词只是更长单词的子串（payload, display）→ 放行
    """
    token_lower = full_token.lower()
    kw_lower = keyword.lower()

    # 白名单检查
    if is_whitelisted(token_lower):
        return False

    # 关键词独立出现
    if token_lower == kw_lower:
        return True

    # 在 token 中找到关键词的位置
    idx = token_lower.find(kw_lower)
    if idx == -1:
        return False

    kw_end = idx + len(kw_lower)

    # 检查关键词前面的边界
    left_ok = False
    if idx == 0:
        # 关键词在开头
        left_ok = True
    else:
        prev_char = full_token[idx - 1]
        if prev_char == '_':
            # 下划线分隔: chat_money
            left_ok = True
        elif prev_char.islower() and full_token[idx].isupper():
            # 驼峰边界: chatMoney (t→M)
            left_ok = True
        elif prev_char.isupper() and full_token[idx].isupper():
            # 全大写: CHAT_MONEY 或 CHATMoney 的情况
            # 需要检查关键词后面是否有边界
            left_ok = True

    if not left_ok:
        return False

    # 检查关键词后面的边界
    right_ok = False
    if kw_end == len(full_token):
        # 关键词在结尾
        right_ok = True
    else:
        next_char = full_token[kw_end]
        if next_char == '_':
            # 下划线分隔: pay_type
            right_ok = True
        elif next_char.isupper():
            # 驼峰边界: payCoins (y→C)
            right_ok = True
        elif full_token[kw_end - 1].isupper() and next_char.islower():
            # 全大写关键词后跟小写: PAYment → 不算，这是单词延续
            # 但 PAY_type → 前面已处理下划线
            right_ok = False

    return right_ok


def check_line(line: str, line_num: int, filepath: str) -> list:
    """检查单行代码是否包含禁止关键词"""
    violations = []

    # 跳过注释行中的非代码内容（仅跳过纯注释行，不跳过含代码的行）
    stripped = line.strip()
    # 单行注释
    if stripped.startswith('//') or stripped.startswith('*') or stripped.startswith('/*'):
        # 注释中也要检查，但给出提示
        is_comment = True
    else:
        is_comment = False

    for rule in BLOCKED_WORDS:
        word = rule["word"]
        mode = rule["mode"]
        pattern = build_pattern(word, mode)

        for m in pattern.finditer(line):
            matched_text = m.group()

            if mode == "compound":
                # compound 模式需要额外判断
                if not is_compound_match(matched_text, word):
                    continue

            # 再次检查完整 token 白名单（所有模式都检查）
            if is_whitelisted(matched_text):
                continue

            violations.append({
                "file": filepath,
                "line": line_num,
                "keyword": word,
                "matched": matched_text,
                "mode": mode,
                "context": line.rstrip(),
                "is_comment": is_comment,
            })

    return violations


def check_file(filepath: str) -> list:
    """检查单个文件"""
    violations = []
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                violations.extend(check_line(line, line_num, filepath))
    except (IOError, OSError) as e:
        print(f"警告: 无法读取 {filepath}: {e}", file=sys.stderr)
    return violations


def get_staged_files() -> list:
    """获取 git staged 的 iOS 源码文件"""
    try:
        result = subprocess.run(
            ['git', 'diff', '--cached', '--name-only', '--diff-filter=ACMR'],
            capture_output=True, text=True, check=True
        )
        files = []
        for f in result.stdout.strip().split('\n'):
            if f and Path(f).suffix in IOS_EXTENSIONS:
                files.append(f)
        return files
    except subprocess.CalledProcessError:
        return []


def get_all_ios_files(root: str = '.') -> list:
    """递归获取所有 iOS 源码文件"""
    files = []
    for dirpath, _, filenames in os.walk(root):
        # 跳过 Pods、build、.git 目录
        if any(skip in dirpath for skip in ['/Pods/', '/build/', '/.git/', '/DerivedData/']):
            continue
        for fname in filenames:
            if Path(fname).suffix in IOS_EXTENSIONS:
                files.append(os.path.join(dirpath, fname))
    return files


def format_violations(violations: list) -> str:
    """格式化输出违规信息"""
    if not violations:
        return "✅ 未发现禁止关键词\n"

    # 按文件分组
    by_file = {}
    for v in violations:
        by_file.setdefault(v['file'], []).append(v)

    lines = []
    lines.append(f"❌ 发现 {len(violations)} 处禁止关键词命中\n")

    for filepath, file_violations in by_file.items():
        lines.append(f"📄 {filepath}")
        for v in file_violations:
            comment_tag = " [注释]" if v['is_comment'] else ""
            lines.append(
                f"  L{v['line']:>4d} | 关键词 '{v['keyword']}' → "
                f"匹配 '{v['matched']}'{comment_tag}"
            )
            lines.append(f"       | {v['context'][:120]}")
        lines.append("")

    return '\n'.join(lines)


def format_json(violations: list) -> str:
    """JSON 格式输出（供其他工具消费）"""
    return json.dumps(violations, ensure_ascii=False, indent=2)


def main():
    args = sys.argv[1:]
    output_json = '--json' in args
    args = [a for a in args if a != '--json']

    if '--staged' in args:
        files = get_staged_files()
        if not files:
            print("没有 staged 的 iOS 源码文件")
            sys.exit(0)
    elif '--all' in args:
        root = args[args.index('--all') + 1] if len(args) > args.index('--all') + 1 else '.'
        files = get_all_ios_files(root)
        if not files:
            print("未找到 iOS 源码文件")
            sys.exit(0)
    elif args:
        files = [f for f in args if os.path.isfile(f)]
    else:
        print("用法:")
        print("  python3 check_blocked_words.py file1.m file2.h ...")
        print("  python3 check_blocked_words.py --staged")
        print("  python3 check_blocked_words.py --all [root_dir]")
        print("  添加 --json 输出 JSON 格式")
        sys.exit(0)

    all_violations = []
    for f in files:
        all_violations.extend(check_file(f))

    if output_json:
        print(format_json(all_violations))
    else:
        print(format_violations(all_violations))

    sys.exit(1 if all_violations else 0)


if __name__ == '__main__':
    main()
