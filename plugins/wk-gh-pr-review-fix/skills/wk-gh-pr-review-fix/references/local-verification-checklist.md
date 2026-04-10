# 本地验证清单

## 目标

在回复 review 或声称“已修复”之前，给出 fresh verification 证据。

## 分层验证顺序

### 1. 最小问题验证

- review 对应的单元测试
- 契约测试
- 针对性的 fixture smoke

必须先跑这层，确认问题真的被覆盖。

### 2. 仓库约定验证

优先检查：
- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`

特别关注：
- 增量编译命令
- 必跑脚本
- staged 检查
- 提交规范

### 3. 范围验证

按改动风险选择：
- 相关模块 smoke
- quick suite
- 更大范围回归

## Git 前检查

如果代码有真实变更：

```bash
git status -sb
git diff -- <changed files>
```

然后再按仓库要求执行：
- staged checks
- 关键词扫描
- 构建或测试

## 回复 review 时需要携带的证据

- 修复所在 commit SHA
- 至少一条直接证明修复生效的命令
- 如有必要，再补一条更大范围 smoke

## 禁止事项

- 没有 fresh verification 就回复 “已修复”
- 只靠旧测试结果或主观判断
- 代码没变却创建空提交
