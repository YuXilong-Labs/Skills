# 实施计划编写规范

设计文档获得用户批准后，用此规范编写实施计划。

## 保存路径

`.claude/plans/YYYY-MM-DD_<主题>_计划.md`

## 文档头部模板

```markdown
# [功能名称] 实施计划

**目标：** [一句话说明要构建什么]

**架构：** [2-3 句说明技术方案]

**技术栈：** [关键技术/库]

---
```

## 文件结构分析（写任务前先做）

梳理涉及的文件：
- 新建哪些文件，各文件的职责
- 修改哪些已有文件（精确到行号范围）
- 一个文件一个职责，避免大文件

文件结构决定任务分解方式，先想清楚再写任务。

## 任务粒度

**每步 2–5 分钟**，以 TDD 为单位拆分：

```markdown
### Task N: [组件名称]

**文件：**
- 新建：`path/to/NewFile.swift`
- 修改：`path/to/Existing.swift:45–80`
- 测试：`path/to/ExistingTests.swift`

- [ ] **Step 1: 写失败测试**

\`\`\`swift
func testSpecificBehavior() {
    let sut = SomeClass()
    XCTAssertEqual(sut.doSomething(), expected)
}
\`\`\`

- [ ] **Step 2: 跑测试确认失败**

命令：`xcodebuild test -scheme MyScheme -only-testing:MyTests/testSpecificBehavior`
预期：FAIL — "use of unresolved identifier 'SomeClass'"

- [ ] **Step 3: 最小实现**

\`\`\`swift
// 只写让测试通过的最小代码
\`\`\`

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 提交**

\`\`\`bash
git add path/to/files
git commit -m "feat: 添加具体功能"
\`\`\`
```

## 禁止占位符

以下内容**不得出现**：
- "TBD"、"TODO"、"待补充"、"fill in"
- "添加适当的错误处理"（必须写出具体的错误处理代码）
- "类似 Task N"（每个 Task 必须是完整的，不得相互引用）
- 没有代码示例的代码步骤
- 引用未在任何 Task 中定义的类型、方法、协议

## 计划自检（写完后执行）

1. **需求覆盖**：设计文档每个需求都有对应 Task 吗？
2. **占位符扫描**：无上述禁止内容
3. **类型一致性**：前后 Task 中同一函数/类命名一致
4. **步骤完整性**：每个 Task 都有测试、实现、验证、提交步骤

## 核心约束

- **DRY**：抽取重复逻辑，不复制代码
- **YAGNI**：不实现设计文档中没有的功能
- **TDD**：测试先行，没有先写失败测试的实现
- **小提交**：每个 Task 至少一个 commit，保持 git 历史可追溯
