---
name: wk-instinct
description: 会话学习系统 — 从 Claude Code 对话中提取可复用模式，保存为原子 instinct 文件（含置信度评分），积累后演化为正式 Skill 或全局规则。
---

# WK-Instinct — 会话学习与模式提取系统

## 概念

**Instinct** = 一条从实际工作中归纳出的、可复用的原子行为模式。

区别于 Skill（完整工作流）：
- Instinct 是**单条规则**，如"这个项目的 delegate 一律用 weak"
- Skill 是**完整流程**，如"iOS TDD 工作流的所有步骤"
- Instinct 有**置信度**（0.0–1.0），置信度高的 instinct 可演化为 Skill 或写入规则

## 存储位置

| 作用域 | 路径 | 适用场景 |
|--------|------|---------|
| 项目级 | `.claude/instincts/` | 只在当前项目生效的模式 |
| 全局 | `~/.claude/instincts/` | 跨项目通用的模式 |

## Instinct 文件格式

```markdown
---
name: delegate-weak-in-this-project
description: 这个项目的所有 delegate 属性必须声明为 weak，不管协议是否显式要求
scope: project          # project | global
confidence: 0.9         # 0.0–1.0，从 0.5 开始，每次验证 +0.1，反例 -0.2
tags: [objective-c, memory, delegate]
created: 2026-06-08
updated: 2026-06-08
evidence:
  - "PR #42 中 reviewer 指出 strong delegate 导致循环引用"
  - "CLAUDE.md 中有 weak delegate 约定"
---

这个项目里，delegate 属性必须使用 `weak` 修饰：

\`\`\`objc
@property (nonatomic, weak) id<SomeDelegate> delegate;
\`\`\`

**不能用 strong**，即使你认为不会循环引用——项目约定如此，统一执行。
```

## 核心命令

### `/learn` — 从当前会话提取 instinct

触发时机：完成一个任务后，或发现了值得记录的模式时。

**执行步骤：**

1. 回顾本次会话的关键决策和发现
2. 识别以下类型的模式：
   - 反复出现的约定（命名、结构、接口设计）
   - 被 reviewer 指出的问题（说明项目有未明确记录的规则）
   - 踩过的坑（避免下次重蹈）
   - 有效的调试/分析方法
3. 检查是否已有相似 instinct（避免重复）：
   ```bash
   ls ~/.claude/instincts/ .claude/instincts/ 2>/dev/null | grep -i <keyword>
   ```
4. 判断作用域：只在本项目有效 → `project`；跨项目通用 → `global`
5. 写入 instinct 文件（从置信度 0.5 开始）

**不值得保存的内容：**
- 代码文件的具体路径、函数名（会随代码演化失效）
- 一次性的修复步骤
- 已在 `CLAUDE.md` 中记录的内容

### `/learn-eval` — 带质量门槛的提取

在 `/learn` 基础上，保存前先自问：

1. **非显而易见性**：这个模式是经验性的、容易被忽略的吗？还是任何人都会自然想到？
2. **可操作性**：看到这条 instinct 的未来 Claude 实例能直接采取行动吗？
3. **作用域准确**：项目级还是全局？搞错了会产生干扰。
4. **置信度校准**：这条模式有几个独立的证据支持？
   - 1 个证据 → 0.5
   - 2 个独立证据 → 0.65
   - reviewer 明确指出 → 额外 +0.15
   - CLAUDE.md 有记录 → 直接 0.9

只有通过质量检查才保存。质量差的 instinct 比没有更糟（产生噪音）。

### `/wk-instinct status` — 查看已有 instinct

```bash
# 列出所有 instinct（项目级 + 全局）
echo "=== 项目级 ===" && ls .claude/instincts/ 2>/dev/null
echo "=== 全局 ===" && ls ~/.claude/instincts/ 2>/dev/null

# 查看特定 instinct
cat .claude/instincts/<name>.md
```

显示格式：
- 按 scope 分组（project / global）
- 按 confidence 降序排列
- 显示 name、description、confidence、tags

### `/wk-instinct evolve` — 演化为正式 Skill

当一组相关 instinct 的置信度都 ≥ 0.8 时，考虑演化：

1. 找出相关的高置信度 instinct
2. 判断它们能否组成一个完整的工作流
3. 如果能 → 用 `/wk-skill-create` 生成 SKILL.md 草稿
4. 演化完成后，原 instinct 文件可以归档或删除

## 置信度管理

| 事件 | 置信度变化 |
|------|-----------|
| 初始创建 | 0.5 |
| 在另一个项目中验证为同样有效 | +0.15 |
| reviewer 明确认可 | +0.15 |
| 发现反例（某场景下不成立） | -0.2 |
| 被写入 CLAUDE.md / 规则文件 | → 0.95（已成为正式规则，instinct 可归档） |

**置信度 < 0.3 的 instinct 应当删除**（反例太多，规律不成立）。

## 使用示例

```
# 刚完成 iOS delegate 相关修复后
/learn
→ 发现模式：这个项目所有 delegate 都需要 weak
→ 保存为 .claude/instincts/delegate-weak.md（project 级，置信度 0.65）

# 两周后再次遇到同样问题
→ 打开 .claude/instincts/delegate-weak.md，置信度从 0.65 → 0.75

# 在另一个项目也发现同样约定
/learn-eval
→ 判定为全局模式，升级为 ~/.claude/instincts/delegate-weak.md
→ 置信度 → 0.85，考虑写入全局规则
```

## 与记忆系统的边界

| 系统 | 存储位置 | 适用内容 |
|------|---------|---------|
| Memory (`~/.claude/projects/.../memory/`) | 用户偏好、项目背景、反馈 | 跨会话的用户/项目上下文 |
| Instinct (`.claude/instincts/`) | 编码模式、技术规律 | 可操作的行为规则，有置信度管理 |
| CLAUDE.md | 长期稳定规则 | instinct 晋升后的最终归宿 |
