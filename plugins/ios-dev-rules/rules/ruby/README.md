# Ruby 编码规范（CocoaPods / Fastlane）

iOS 项目中 Ruby 脚本（Podfile、Fastfile、Rakefile 等）的编码规范规则集，安装后作为 Claude Code / Codex 的 rules 生效。

## 包含规则

| 文件 | 内容 |
|------|------|
| `coding-style.md` | 格式化、命名、Podfile/Fastfile 约定、Gem 依赖管理 |
| `hooks.md` | PostToolUse rubocop 自动格式化 hook 配置 |
| `patterns.md` | Ruby 脚本设计模式（lane 组织、plugin 封装） |
| `security.md` | 安全规范（证书管理、密钥存储、CI 环境变量） |
| `testing.md` | 测试规范（RSpec、Fastlane action 测试） |

## 关键配置

- 缩进：2 空格（Ruby 社区标准）
- Podfile：按功能分组 pod，注释说明用途
- Fastlane：lane 命名清晰，复杂逻辑提取为 action
- 密钥：禁止硬编码，使用 `dotenv` 或 CI 环境变量

## 安装

```bash
# 随 ios-dev-rules 一起安装
./install.sh ios-dev-rules
```

安装后位于 `~/.claude/rules/ruby/`。
