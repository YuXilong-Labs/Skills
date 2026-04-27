# Swift 编码规范

iOS Swift 编码规范规则集，安装后作为 Claude Code / Codex 的 rules 生效。

## 包含规则

| 文件 | 内容 |
|------|------|
| `coding-style.md` | 格式化、不可变性、命名、错误处理、并发、Swift 6.2、类型擦除、注释、约束、import 顺序、可选类型安全解包、类成员组织顺序、闭包简洁性 |
| `hooks.md` | PostToolUse swift-format 自动格式化 hook 配置 |
| `patterns.md` | Swift 设计模式与架构约定 |
| `security.md` | 安全规范（Keychain、ATS、敏感数据处理） |
| `testing.md` | 测试规范（XCTest、Swift Testing、覆盖率） |

## 关键配置

- 缩进：4 空格
- 不可变性：优先 `let`，优先 `struct`
- 约束：SnapKit + leading/trailing
- 并发：Swift 6 strict concurrency + 6.2 `@concurrent`
- 可选类型：优先 `guard let` / `if let`，禁止滥用 `!`
- import 顺序：系统库 → 第三方库 → 内部组件
- 方法名禁止 `bt_` 前缀

## 安装

```bash
# 随 ios-dev-rules 一起安装
./install.sh ios-dev-rules
```

安装后位于 `~/.claude/rules/swift/`。
