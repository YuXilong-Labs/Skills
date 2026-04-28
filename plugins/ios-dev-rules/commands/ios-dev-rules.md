---
description: 安装 iOS 开发规则包（Objective-C / Swift / Ruby）到 ~/.claude/rules/ 和 ~/.codex/rules/
allowed-tools: Bash
---

# ios-dev-rules

iOS 开发三语言编码规范规则包。

## 版本检测

!`bash ~/.claude/scripts/ios-dev-rules/check-update.sh 2>/dev/null || echo "未安装检测脚本，请先运行 ./install.sh ios-dev-rules"`

## 安装

```bash
# 通过 Skills 仓库安装
./install.sh ios-dev-rules

# 远程一键安装
curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash -s -- ios-dev-rules
```

## 包含规则

| 语言 | 文件匹配 | 覆盖内容 |
|------|----------|----------|
| Objective-C | `*.h`, `*.m`, `*.mm` | 命名、属性、内存管理、pragma mark、nullability |
| Swift | `*.swift`, `Package.swift` | Swift 6.2 并发、iOS 26、SwiftUI、协议导向 |
| Ruby | `Gemfile`, `Podfile`, `Fastfile`, `*.podspec`, `*.rb` | CocoaPods、Fastlane、Bundler、RuboCop |

## 卸载

```bash
./install.sh --uninstall ios-dev-rules
```
