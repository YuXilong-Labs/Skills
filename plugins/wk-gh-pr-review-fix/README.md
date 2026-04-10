# wk-gh-pr-review-fix

GitHub Pull Request review 闭环处理 Skill。

## 功能

一键收口当前分支 PR 的 review 反馈：

1. 拉取 thread-aware review 状态
2. 识别 unresolved actionable threads
3. 核实评论是否成立
4. 先补测试再修复代码
5. 按仓库约定做本地验证
6. 推送分支更新
7. 在线程中回复并 resolve

## 使用

```bash
/wk-gh-pr-review-fix
```

也支持带参数：

```bash
/wk-gh-pr-review-fix mode=inspect
/wk-gh-pr-review-fix pr=123
/wk-gh-pr-review-fix repo=owner/name pr=123
```

## 适用场景

- “拉取当前 PR review 结果并修复”
- “把 unresolved review threads 处理掉”
- “修完以后本地验证、推送并标记解决”

## 依赖

- `gh` CLI 已登录
- 仓库对 GitHub API 有访问权限
- 本地仓库能执行项目自己的测试与构建命令
