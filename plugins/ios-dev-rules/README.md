# ios-dev-rules

iOS 开发三语言编码规范规则包，覆盖 Objective-C、Swift、Ruby（CocoaPods/Fastlane）。

安装后自动注入 `~/.claude/rules/` 和 `~/.codex/rules/`，Claude Code 按文件类型自动激活对应规则。

## 安装

```bash
./install.sh ios-dev-rules
```

## 规则结构

每种语言包含 6 个规则文件，继承 `common/` 通用规则：

- `coding-style.md` — 格式化、命名、文件结构
- `simplicity.md` — 简单性优先、禁止过度抽象/封装、量化复杂度阈值、函数内逻辑注释规范
- `security.md` — 密钥管理、输入验证、传输安全
- `patterns.md` — 设计模式、架构约定
- `hooks.md` — PostToolUse 自动化（格式化、lint）
- `testing.md` — 测试框架、覆盖率、TDD
