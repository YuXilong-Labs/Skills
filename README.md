# Skills — Claude Code 技能仓库

面向 iOS/macOS 开发的 Claude Code Skills 集合，同时支持 OpenAI Codex CLI。

## 可用 Skills

### 开发工作流

| Skill | 命令 | 描述 |
|-------|------|------|
| `wk-brainstorm` | `/wk-brainstorm` | **实现前设计探索** — 需求澄清、方案对比、设计文档输出，防止基于未验证假设开工 |
| `wk-tdd` | `/wk-tdd` | **iOS/macOS TDD 工作流** — 强制先写测试（RED→GREEN→REFACTOR），覆盖 Swift Testing / XCTest / OCMock，内置覆盖率验证 |
| `wk-review` | `/wk-review` | **本地代码修改 Review** — 基于 git diff 审查逻辑 bug、crash 风险、内存泄漏、性能问题（Agent 并行架构，7 大维度） |
| `wk-gh-pr-review-fix` | `/wk-gh-pr-review-fix` | **GitHub PR review 闭环** — 拉取未解决 review threads，修复、本地验证、推送并在线程中回复 resolve |
| `wk-crash-repro-fix` | `/wk-crash-repro-fix` | **iOS Crash 闭环排查** — 根因定位、稳定复现、修复落地、回归验证全流程 |
| `wk-xcodebuild` | `/wk-xcodebuild` | **xcodebuild 智能包装** — 自动选 USB 真机目标（无则回退 Mac），rtk 风格精简 build/test 输出（实测省 ~99.7% token）；test 后追加 xcresult 权威摘要（XCTest/Swift Testing 统一计数），`xcb result`/`xcb cov` 摘要测试结果与覆盖率 |

### 代码审计

| Skill | 命令 | 描述 |
|-------|------|------|
| `wk-scan-clean-code` | `/wk-scan-clean-code` | ObjC/Swift 代码清理审计 — 识别可安全删除的字段、方法、文件 |
| `wk-symbol-reference-scan` | `/wk-symbol-reference-scan` | 全局符号引用扫描 — 覆盖源码、Framework Headers、二进制 strings |
| `ios-blocked-words-check` | `/ios-blocked-words-check` | App Store 审核合规检查 — 智能匹配 60+ 高危敏感词 |

### 组件库 & 文档

| Skill | 命令 | 描述 |
|-------|------|------|
| `wk-ios-component-reuse` | `/wk-ios-component-reuse` | 组件库复用工作流 — 选型、实现、审查、迁移阶段强制"先检索组件再行动" |
| `wk-lark-wiki` | `/wk-lark-wiki` | iOS 组件库 API 文档生成、AI 润色与飞书知识库上传（单组件） |
| `wk-lark-wiki-batch` | `/wk-lark-wiki-batch` | 批量生成 main 分支基础组件 API 文档，Haiku 深度润色并上传飞书 Wiki |

### Proto & 工程化

| Skill | 命令 | 描述 |
|-------|------|------|
| `wk-sync-pb` | `/wk-sync-pb` | 同步上游 proto submodule 并重新生成 ObjC Protobuf 代码（含敏感词检查与自动提交） |

### Skill 生态维护

| Skill | 命令 | 描述 |
|-------|------|------|
| `wk-instinct` | `/learn` `/learn-eval` | **会话学习系统** — 从对话中提取可复用模式，保存为原子 instinct（含置信度管理），积累后演化为正式 Skill |
| `wk-skill-create` | `/wk-skill-create` | **Skill 生成工具** — 分析 git 历史提取编码模式，或将高置信度 instinct 演化为完整 SKILL.md |

## Rules（编码规范）

| Rules | 命令 | 描述 | 覆盖语言 |
|-------|------|------|----------|
| `ios-dev-rules` | `/ios-dev-rules` | iOS 三语言编码规范 — 命名、属性、内存管理、约束、注释、遍历安全、集合防护等 | ObjC / Swift / Ruby |

## Hooks

| Hook | 类型 | 触发时机 | 描述 |
|------|------|----------|------|
| `ios-blocked-words-hook` | `PostToolUse` | `Edit`/`Write` iOS 文件后 | 自动触发禁止关键词检查（双端），非阻塞，发现违规时注入警告并禁止 git commit |
| `wk-xcodebuild`（内置） | `PreToolUse` | 执行裸 `xcodebuild`、`swift build`/`swift test` 或 `xcresulttool get test-results` 前 | 静默改写为包装器（`allow`+`updatedInput`）；`WK_XCB_BYPASS=1` 可逃生 |

## 安装

### 方式 1：远程一键安装（推荐）

同时安装到 Claude Code (`~/.claude/`) 和 Codex (`~/.codex/`)：

```bash
curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash
```

### 方式 2：Plugin Marketplace（Claude Code）

> 需要 Claude Code ≥ 1.0.33

```
# 添加 marketplace
/plugin marketplace add YuXilong-Labs/Skills

# 按需安装
/plugin install wk-brainstorm@yuxilong-skills
/plugin install wk-tdd@yuxilong-skills
/plugin install wk-review@yuxilong-skills
/plugin install wk-gh-pr-review-fix@yuxilong-skills
/plugin install wk-crash-repro-fix@yuxilong-skills
/plugin install wk-xcodebuild@yuxilong-skills
/plugin install wk-scan-clean-code@yuxilong-skills
/plugin install wk-symbol-reference-scan@yuxilong-skills
/plugin install ios-blocked-words-check@yuxilong-skills
/plugin install ios-blocked-words-hook@yuxilong-skills
/plugin install wk-ios-component-reuse@yuxilong-skills
/plugin install wk-lark-wiki@yuxilong-skills
/plugin install wk-sync-pb@yuxilong-skills
/plugin install wk-instinct@yuxilong-skills
/plugin install wk-skill-create@yuxilong-skills
/plugin install ios-dev-rules@yuxilong-skills
```

### 方式 3：Codex 原生 Marketplace

> 需要 Codex CLI ≥ 0.120

```bash
# 添加 marketplace
codex plugin marketplace add YuXilong-Labs/Skills
codex plugin marketplace add ./   # 仓库根目录本地添加

# 查看与安装
codex plugin list
codex plugin add wk-brainstorm@yuxilong-skills
codex plugin add wk-xcodebuild@yuxilong-skills
codex plugin add wk-review@yuxilong-skills
```

Codex 目录清单位于 `.agents/plugins/marketplace.json`（14 个 skill 类 plugin）。
`ios-dev-rules`（规则类）与 `ios-blocked-words-hook`（hook 跨 plugin 依赖 check 脚本）
不编入原生 catalog，请用方式 1 的 `install.sh` 安装。

### 方式 4：手动安装

```bash
git clone https://github.com/YuXilong-Labs/Skills.git
cd Skills

# 安装所有 Skills（Claude Code + Codex）
./install.sh

# 安装指定 Skill
./install.sh wk-brainstorm
./install.sh wk-tdd
./install.sh wk-review
./install.sh wk-gh-pr-review-fix
./install.sh wk-crash-repro-fix
./install.sh wk-xcodebuild
./install.sh wk-scan-clean-code
./install.sh wk-symbol-reference-scan
./install.sh ios-blocked-words-check
./install.sh ios-blocked-words-hook
./install.sh wk-ios-component-reuse
./install.sh wk-lark-wiki
./install.sh wk-sync-pb
./install.sh wk-instinct
./install.sh wk-skill-create
./install.sh ios-dev-rules
```

## 使用示例

### 开发工作流

```
# 实现前先探索设计
/wk-brainstorm 我需要一个消息重试机制
/wk-brainstorm 把 IM 消息存储从内存迁移到 SQLite

# TDD 工作流
/wk-tdd feature=消息发送状态追踪 framework=swift-testing
/wk-tdd 帮我用 TDD 实现一个带超时的网络请求封装

# 代码审查
/wk-review
/wk-review scope=staged
/wk-review focus=crash,memory

# PR review 闭环
/wk-gh-pr-review-fix
/wk-gh-pr-review-fix mode=inspect
/wk-gh-pr-review-fix repo=YuXilong-Labs/LLVM-Hikari pr=14

# Crash 排查
/wk-crash-repro-fix 帮我分析这个 crash，EXC_BAD_ACCESS 在 BTDNSManager dealloc 时触发

# xcodebuild（自动改写，通常无需手动调用）
/wk-xcodebuild scheme=MyApp
```

### 代码审计

```
# 代码清理审计
/wk-scan-clean-code target_file=Models/UserModel.h mode=model-fields
/wk-scan-clean-code project_root=. mode=dead-code
/wk-scan-clean-code project_root=. mode=full

# 符号引用扫描
/wk-symbol-reference-scan keywords=FeatureX project_root=.
/wk-symbol-reference-scan keywords=FeatureX,FeatureY mode=batch

# 敏感词检查
/ios-blocked-words-check file=Classes/PB/SendGift.pbobjc.m
/ios-blocked-words-check --staged
```

### 组件库 & 文档

```
# 组件库复用
/wk-ios-component-reuse mode=selection requirement=做一个带分页列表的页面
/wk-ios-component-reuse mode=implementation requirement=实现头像圆角缓存加载

# Lark Wiki 文档
/wk-lark-wiki component=BTBaseKit pods_dir=/path/to/Pods wiki_node=wikcnXXXX
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX

# Proto 同步
/wk-sync-pb
```

### Skill 生态维护

```
# 从当前会话提取 instinct
/learn
/learn delegate 内存管理

# 带质量门槛的提取
/learn-eval

# 生成新 Skill
/wk-skill-create 网络请求错误处理
/wk-skill-create mode=instinct delegate 内存管理
```

### ios-dev-rules

```bash
# 安装规则
./install.sh ios-dev-rules

# 查看当前版本
/ios-dev-rules

# 手动升级
/ios-dev-rules update
```

规则安装后 Claude Code 会在每次编辑文件时后台自动检查更新（每日最多一次）。

### wk-lark-wiki-batch 说明

```
# 默认：Haiku 深度润色 + 上传（未变更组件自动跳过）
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX

# 预览（不真正调用 lark-cli）
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX preview=true

# 跳过润色
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX no_polish=true

# 强制重做
/wk-lark-wiki-batch pods_dir=/path/to/Pods wiki_node=wikcnXXXX force=true
```

## 管理

```bash
# 列出所有可用 Skills
./install.sh --list

# 卸载指定 Skill
./install.sh --uninstall wk-scan-clean-code
```

## 目录结构

```
Skills/
├── .claude-plugin/
│   └── marketplace.json              # Claude Plugin Marketplace 清单
├── .agents/plugins/
│   └── marketplace.json              # Codex Plugin Marketplace 清单
├── plugins/                          # 每个 Skill/Hook 独立为一个 plugin
│   ├── wk-brainstorm/                # 实现前设计探索
│   ├── wk-tdd/                       # iOS/macOS TDD 工作流
│   ├── wk-review/                    # 本地代码修改 Review
│   ├── wk-gh-pr-review-fix/          # GitHub PR review 闭环
│   ├── wk-crash-repro-fix/           # iOS Crash 闭环排查
│   ├── wk-xcodebuild/                # xcodebuild 智能包装（含 PreToolUse hook）
│   ├── wk-scan-clean-code/           # 代码清理审计
│   ├── wk-symbol-reference-scan/     # 全局符号引用扫描
│   ├── wk-ios-component-reuse/       # 组件库复用工作流
│   ├── wk-lark-wiki/                 # API 文档生成与飞书上传（单组件）
│   ├── wk-sync-pb/                   # Proto 同步与 ObjC 代码生成
│   ├── wk-instinct/                  # 会话学习系统（/learn, /learn-eval）
│   ├── wk-skill-create/              # Skill 生成工具
│   ├── ios-blocked-words-check/      # 禁止关键词检查 Skill
│   ├── ios-blocked-words-hook/       # 禁止关键词 PostToolUse Hook
│   └── ios-dev-rules/                # iOS 三语言编码规范（ObjC/Swift/Ruby）
├── install.sh                        # 双目标安装 + curl 远程安装
└── README.md
```

每个 plugin 目录结构：

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json                   # Claude Code Plugin 清单
├── .codex-plugin/
│   └── plugin.json                   # Codex Plugin 清单（含 skills/interface 字段）
├── skills/
│   └── plugin-name/
│       ├── SKILL.md                  # Skill 主定义（frontmatter + 工作流）
│       └── references/               # 参考文档（按需）
├── commands/
│   └── plugin-name.md                # 斜杠命令入口（mode: skill）
└── hooks/                            # Hook 配置（仅 Hook 类 plugin）
    └── hooks.json
```

## 设计原则

- **独立 Plugin** — 每个 Skill 是独立 plugin，命令以 `/wk-` 前缀区分
- **双目标安装** — 同时安装到 Claude Code 和 Codex
- **证据驱动** — 每个结论必须附带搜索证据，可验证、可追溯
- **宁可保守** — 不确定时归入"需谨慎确认"，不误删
- **只读不改** — Skill 只输出报告/建议，不自动修改用户代码（wk-tdd / wk-gh-pr-review-fix / wk-crash-repro-fix 等执行类 Skill 除外）
- **可扩展** — 新增 Skill 只需在 `plugins/` 下添加子目录，并注册到两个 marketplace.json

## License

MIT
