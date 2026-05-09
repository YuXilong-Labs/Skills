---
description: 安装 iOS 开发规则包（Objective-C / Swift / Ruby）到 ~/.claude/rules/ 和 ~/.codex/rules/
allowed-tools: Bash
argument-hint: "[update]"
---

# ios-dev-rules

iOS 开发三语言编码规范规则包。

## 执行逻辑

根据用户是否传入 `update` 参数，执行不同操作：

- **无参数**（`/ios-dev-rules`）：查看当前版本状态
- **`update` 参数**（`/ios-dev-rules update`）：立即升级到最新版本

如果用户传入了 `update`，执行：
!`bash ~/.claude/scripts/ios-dev-rules/check-and-upgrade.sh --mode=force 2>/dev/null || echo "未安装检测脚本，请先运行 ./install.sh ios-dev-rules"`

否则（无参数或其他参数），执行：
!`bash ~/.claude/scripts/ios-dev-rules/check-and-upgrade.sh --mode=check 2>/dev/null || echo "未安装检测脚本，请先运行 ./install.sh ios-dev-rules"`

## 包含规则

| 语言 | 文件匹配 | 覆盖内容 |
|------|----------|----------|
| Objective-C | `*.h`, `*.m`, `*.mm` | 命名、属性、内存管理、pragma mark、nullability、复杂度与可读性约束 |
| Swift | `*.swift`, `Package.swift` | Swift 6.2 并发、iOS 26、SwiftUI、协议导向、复杂度与可读性约束 |
| Ruby | `Gemfile`, `Podfile`, `Fastfile`, `*.podspec`, `*.rb` | CocoaPods、Fastlane、Bundler、RuboCop |

## 自动升级

规则已配置后台自动检查（每日一次，编辑文件时触发）。升级日志：`~/.claude/rules/.ios-dev-rules.upgrade.log`

## 安装

```bash
./install.sh ios-dev-rules
# 或远程一键安装
curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash -s -- ios-dev-rules
```

## 卸载

```bash
./install.sh --uninstall ios-dev-rules
```
