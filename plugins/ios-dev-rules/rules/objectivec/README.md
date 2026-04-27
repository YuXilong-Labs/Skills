# Objective-C 编码规范

iOS Objective-C 编码规范规则集，安装后作为 Claude Code / Codex 的 rules 生效。

## 包含规则

| 文件 | 内容 |
|------|------|
| `coding-style.md` | 格式化、命名、属性声明、大括号风格、文件结构、pragma mark、视图初始化、约束、Block 循环引用、属性访问、注释、枚举、泛型、集合初始化、遍历安全、数据防护、NSNotification、NSTimer、分类前缀、变量声明、提前返回、单一原则、CF 资源释放 |
| `hooks.md` | PostToolUse clang-format 自动格式化 hook 配置 |
| `patterns.md` | ObjC 设计模式与架构约定 |
| `security.md` | 安全规范（空值防护、线程安全、敏感数据处理） |
| `testing.md` | 测试规范（XCTest、覆盖率、Mock） |

## 关键配置

- 缩进：4 空格
- 列宽：120 字符
- 大括号：方法 Allman / 控制语句 K&R
- 约束：Masonry + leading/trailing
- 属性访问：优先 `_ivar`，Block 内用 `weakSelf`
- 集合：非静态数据禁止字面量初始化
- 格式化：`.clang-format` 配置文件随规则安装

## 安装

```bash
# 随 ios-dev-rules 一起安装
./install.sh ios-dev-rules
```

安装后位于 `~/.claude/rules/objectivec/`。
