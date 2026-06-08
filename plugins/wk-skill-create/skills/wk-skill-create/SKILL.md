---
name: wk-skill-create
description: Skill 生成工具 — 分析 git 历史和现有代码提取编码模式，生成符合本仓库规范的 SKILL.md 草稿；也用于从现有 instinct 集合演化为完整 Skill。
---

# WK-Skill-Create — Skill 生成工具

## 概览

两种使用模式：
1. **Git 分析模式**：分析 git 历史提取编码模式 → 生成 SKILL.md 草稿
2. **Instinct 演化模式**：把一组高置信度 instinct 组织为完整 Skill

## 输入参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `mode` | `git` | `git`（分析提交历史）/ `instinct`（从 instinct 演化） |
| `commits` | `200` | 分析最近 N 条提交（git 模式） |
| `topic` | 自动推断 | 要提取的主题，如 "网络请求"、"数据库操作" |
| `output` | `./plugins/wk-<name>/` | 输出目录 |
| `scope` | `project` | `project`（项目专用）/ `global`（通用） |

## 模式一：Git 分析模式

### Step 1：收集 Git 数据

```bash
# 近期提交及变更文件
git log --oneline -n ${COMMITS:-200} --name-only \
  --pretty=format:"%H|%s|%ad" --date=short

# 提交频率最高的文件（最可能包含规律）
git log --oneline -n 200 --name-only \
  | grep -v "^$" | grep -v "^[a-f0-9]" \
  | sort | uniq -c | sort -rn | head -20

# 提交消息模式（提取类型和命名约定）
git log --oneline -n 200 | cut -d' ' -f2- | head -50

# 按文件扩展名过滤（iOS 专注 .swift/.m/.h）
git log --oneline -n 200 --name-only \
  | grep -E '\.(swift|m|h)$' | sort | uniq -c | sort -rn | head -20
```

### Step 2：分析模式

重点识别以下规律：

**结构性模式：**
- 文件命名约定（前缀、后缀、分组方式）
- 目录组织方式（按功能 vs 按类型）
- 类/结构体命名规则

**代码质量模式：**
- 哪类修改最常出现在 fix/refactor 提交中（说明这里容易犯错）
- 哪些文件经常一起修改（强耦合信号）
- 哪类测试被频繁补充（说明有遗漏的场景）

**工作流模式：**
- 提交粒度（大提交 vs 小提交）
- 测试是否与功能同步提交
- 提交消息类型分布（feat/fix/refactor 比例）

### Step 3：生成 SKILL.md 草稿

根据分析结果，按以下模板生成：

```markdown
---
name: wk-<name>
description: <一句话说明这个 Skill 解决什么问题，触发时机>
---

# WK-<Name>

## 何时使用

[从 git 历史中识别出的触发场景]

## 核心模式

[从提交历史中提取的关键约定，附代码示例]

## 工作流程

[按步骤描述，每步可独立验证]

## 常见错误

[从 fix 类提交中归纳出的反模式]

## 验证方式

[如何确认遵循了这个 Skill]
```

### Step 4：写入项目

生成的文件按标准 plugin 结构放置：

```
plugins/wk-<name>/
  .claude-plugin/plugin.json
  .codex-plugin/plugin.json
  skills/wk-<name>/
    SKILL.md
    references/        # 按需
  commands/wk-<name>.md
```

**注意**：生成的是**草稿**，需要人工审核和补充：
- 代码示例是否准确
- 触发时机描述是否准确
- 是否遗漏了重要约定

## 模式二：Instinct 演化模式

当有一组相关 instinct 置信度均 ≥ 0.8 时触发。

### Step 1：收集相关 Instinct

```bash
# 列出所有 instinct
ls .claude/instincts/ ~/.claude/instincts/ 2>/dev/null

# 找出相关的高置信度 instinct
grep -l "confidence: 0\.[89]" .claude/instincts/*.md 2>/dev/null
grep -l "confidence: 1\." .claude/instincts/*.md 2>/dev/null
```

### Step 2：判断是否构成完整工作流

一组 instinct 能演化为 Skill 的条件：
- 覆盖同一个领域的多个方面
- 合在一起形成一个可操作的流程
- 每条 instinct 都有足够的证据支撑

### Step 3：生成 Skill

把 instinct 的内容组织为 SKILL.md，注意：
- 每条 instinct 的 body 变成 Skill 中的一个规则或步骤
- 保留 evidence 作为规则背后的"为什么"注释
- 删除置信度（Skill 不需要置信度，它已经是确定的规则）

### Step 4：归档原 Instinct

演化完成后，处理原 instinct 文件：
- 在 instinct 文件头部添加 `evolved_to: wk-<name>` 字段
- 可选：删除原 instinct（Skill 已是更好的引用）

## Skill 质量标准

生成的 Skill 必须通过：

- [ ] **可触发性**：description 清晰描述何时使用，Claude 能准确判断何时调用
- [ ] **可操作性**：每个步骤都有具体的命令或代码示例，不留 TBD
- [ ] **自包含性**：不引用外部 Skill 就能独立执行
- [ ] **可验证性**：有明确的成功标准或验证命令
- [ ] **无冗余**：不重复 CLAUDE.md 或全局规则已有的内容

## 发布到仓库

新 Skill 需要同步更新以下文件：

1. `.claude-plugin/marketplace.json` — 添加插件条目
2. `.agents/plugins/marketplace.json` — 添加 Codex 条目
3. `README.md` — 添加到 Skills 表格、Commands 表格、安装命令列表

参见 `CLAUDE.md` 中的"新增 Skill 流程"。
