# Skills — Claude Code 技能仓库

面向 iOS/macOS 开发的 Claude Code Skills 集合。

## 可用 Skills

| Skill | 描述 | 模式 | MCP 依赖 |
|-------|------|------|----------|
| `wk-scan-clean-code` | 代码清理审计 — 识别 ObjC/Swift 工程中可安全删除的字段、方法、文件 | `model-fields` `dead-code` `unused-files` `full` | 无 |
| `wk-ios-component-reuse` | 组件库复用工作流 — 选型、实现、审查、迁移阶段强制"先检索组件再行动" | `selection` `implementation` `review` `migration` | `ios-components` |
| `wk-symbol-reference-scan` | 全局符号引用扫描 — 覆盖源码、Framework Headers、二进制 strings | `single` `batch` `related` | 无 |
| `wk-review` | 本地代码修改 Review — 基于 git diff 审查 bug、crash、内存泄漏、性能问题 | 默认审查全部 diff | 无 |
| `wk-sync-pb` | 同步上游 proto submodule 并重新生成 ObjC Protobuf 代码 | 自动化流程（拉取→生成→检查→提交） | 无 |
| `ios-blocked-words-check` | App Store 审核合规禁止关键词检查 — 智能匹配 60+ 高危敏感词 | 指定文件 / `--staged` / `--all` | 无 |
| `wk-lark-wiki` | iOS 组件库 API 文档生成、AI 润色与飞书知识库上传 | `full` `generate` `polish` `upload` | 无 |
| `wk-crash-repro-fix` | iOS Crash 闭环排查 — 根因定位、稳定复现、修复落地、回归验证 | 端到端流程（5步） | 无 |
| `wk-gh-pr-review-fix` | GitHub PR review 闭环处理 — 拉取未解决 review、修复、本地验证、推送并回复解决 | `inspect` `fix-all` `reply-only` | 无 |

## Hooks

| Hook | 类型 | 触发时机 | 描述 |
|------|------|----------|------|
| `ios-blocked-words-hook` | `PostToolUse` | `Edit` / `Write` iOS 源码文件后 | 自动触发禁止关键词检查，非阻塞，发现违规时注入警告并禁止 git commit |

## Commands（斜杠命令）

| 命令 | 描述 | 对应 Skill |
|------|------|-----------|
| `/wk-scan-clean-code` | 对 ObjC/Swift 工程执行代码清理审计，识别可安全删除的字段、方法、文件 | `wk-scan-clean-code` |
| `/wk-ios-component-reuse` | iOS 组件库复用工作流 — 选型、实现、审查、迁移阶段强制先检索组件再行动 | `wk-ios-component-reuse` |
| `/wk-symbol-reference-scan` | iOS 工程全局符号引用扫描 — 覆盖源码、Framework 二进制、Headers | `wk-symbol-reference-scan` |
| `/wk-review` | 对本地 git 修改进行代码审查，关注逻辑 bug、crash 风险、内存泄漏、性能问题 | `wk-review` |
| `/wk-sync-pb` | 同步上游 proto submodule 并重新生成 ObjC Protobuf 代码（含敏感词检查与自动提交） | `wk-sync-pb` |
| `/ios-blocked-words-check` | 检查 iOS 源码中的 App Store 审核禁止关键词（赌博、支付、金融等敏感词） | `ios-blocked-words-check` |
| `/wk-lark-wiki` | iOS 组件库 API 文档生成 + AI 润色 + 飞书知识库上传 | `wk-lark-wiki` |
| `/wk-crash-repro-fix` | iOS Crash 端到端闭环排查（根因→复现→修复→回归） | `wk-crash-repro-fix` |
| `/wk-gh-pr-review-fix` | GitHub PR review 闭环处理（拉 review→修复→验证→推送→回复并 resolve） | `wk-gh-pr-review-fix` |

## 安装

### 方式 1：远程一键安装（推荐）

同时安装到 Claude Code (`~/.claude/`) 和 Codex (`~/.codex/`)：

```bash
curl -fsSL https://raw.githubusercontent.com/YuXilong-Labs/Skills/main/install.sh | bash
```

### 方式 2：Plugin Marketplace

> 需要 Claude Code ≥ 1.0.33

```
# 添加 marketplace
/plugin marketplace add YuXilong-Labs/Skills

# 安装 plugin
/plugin install wk-scan-clean-code@yuxilong-skills
/plugin install wk-ios-component-reuse@yuxilong-skills
/plugin install wk-symbol-reference-scan@yuxilong-skills
/plugin install wk-review@yuxilong-skills
/plugin install wk-sync-pb@yuxilong-skills
/plugin install ios-blocked-words-check@yuxilong-skills
/plugin install ios-blocked-words-hook@yuxilong-skills
/plugin install wk-lark-wiki@yuxilong-skills
/plugin install wk-crash-repro-fix@yuxilong-skills
/plugin install wk-gh-pr-review-fix@yuxilong-skills
```

### 方式 3：手动安装

```bash
# 克隆仓库
git clone https://github.com/YuXilong-Labs/Skills.git
cd Skills

# 安装所有 Skills（Claude Code + Codex）
./install.sh

# 安装指定 Skill
./install.sh wk-scan-clean-code
./install.sh wk-ios-component-reuse
./install.sh wk-symbol-reference-scan
./install.sh wk-review
./install.sh wk-sync-pb
./install.sh ios-blocked-words-check
./install.sh ios-blocked-words-hook
./install.sh wk-lark-wiki
./install.sh wk-crash-repro-fix
./install.sh wk-gh-pr-review-fix

## 使用

安装后在 Claude Code 中使用：

```
# wk-scan-clean-code
/wk-scan-clean-code target_file=Models/UserModel.h mode=model-fields
/wk-scan-clean-code project_root=. mode=dead-code
/wk-scan-clean-code project_root=. mode=unused-files
/wk-scan-clean-code project_root=. mode=full

# wk-ios-component-reuse
/wk-ios-component-reuse mode=selection requirement=做一个带分页列表的页面
/wk-ios-component-reuse mode=implementation requirement=实现头像圆角缓存加载
/wk-ios-component-reuse mode=review requirement=检查PR是否有自定义图片下载器
/wk-ios-component-reuse mode=migration requirement=把自定义缓存迁移到基础组件

# wk-symbol-reference-scan
/wk-symbol-reference-scan keywords=FeatureX project_root=.
/wk-symbol-reference-scan keywords=FeatureX,FeatureY mode=batch output_file=ref.md
/wk-symbol-reference-scan keywords=FeatureX mode=related include_third_party=true

# wk-review
/wk-review
/wk-review scope=staged
/wk-review commit=HEAD~3..HEAD

# wk-sync-pb
/wk-sync-pb

# ios-blocked-words-check
/ios-blocked-words-check file=Classes/PB/SendGift.pbobjc.m
/ios-blocked-words-check --staged
/ios-blocked-words-check --all Classes/
```

也支持自然语言：

```
/wk-scan-clean-code 帮我检查 UserModel.h 里哪些字段没用了
/wk-ios-component-reuse 实现上传功能，不要重复造轮子
/wk-symbol-reference-scan 帮我查一下 FeatureX 在工程里哪些地方用到了，包括二进制 framework
/wk-review 帮我审查一下这次改动有没有内存泄漏
/wk-sync-pb 同步一下上游 proto 并重新生成代码
/ios-blocked-words-check 帮我检查 SendGift.pbobjc.m 里有没有敏感词
/wk-crash-repro-fix 帮我分析这个 crash，EXC_BAD_ACCESS 在 dealloc 时触发
/wk-gh-pr-review-fix 拉一下当前 PR review 结果并修复
```

### wk-lark-wiki

```
# 完整流程：生成 + 润色 + 上传
/wk-lark-wiki pods_dir=/path/to/Pods wiki_node=wikcnXXXX

# 仅润色现有文档
/wk-lark-wiki mode=polish

# 处理单个组件
/wk-lark-wiki component=BTBaseKit pods_dir=/path/to/Pods wiki_node=wikcnXXXX

# 自然语言
/wk-lark-wiki 帮我更新 BTBaseKit 的文档到飞书
```

### wk-crash-repro-fix

```
# 提供崩溃栈分析
/wk-crash-repro-fix crash_type=EXC_BAD_ACCESS stack="BTDNSManager dealloc thread:bg"

# 指定场景复现
/wk-crash-repro-fix scenario=前后台切换时DNS定时器野指针 scheme=BTNetwork-Example

# 自然语言
/wk-crash-repro-fix 帮我分析这个 crash，EXC_BAD_ACCESS 在 BTDNSManager dealloc 时触发
/wk-crash-repro-fix 先写一个稳定复现用例，定时器和 dealloc 竞态
/wk-crash-repro-fix 开始修复并验证，跑高压回归
```

### wk-gh-pr-review-fix

```
# 默认处理当前分支 PR 的 unresolved actionable review
/wk-gh-pr-review-fix

# 只查看当前状态
/wk-gh-pr-review-fix mode=inspect

# 指定 PR
/wk-gh-pr-review-fix repo=YuXilong-Labs/LLVM-Hikari pr=14

# 自然语言
/wk-gh-pr-review-fix 拉取当前 PR review 结果并修复、本地验证后推送并标记解决
```

## 管理

```bash
# 列出所有可用 Skills
./install.sh --list

# 卸载指定 Skill（同时清理 Claude Code 和 Codex）
./install.sh --uninstall wk-scan-clean-code
```

## 目录结构

```
Skills/
├── .claude-plugin/
│   └── marketplace.json          # Plugin Marketplace 清单
├── plugins/                      # 每个 Skill/Hook 独立为一个 plugin
│   ├── wk-scan-clean-code/       # 代码清理审计
│   ├── wk-ios-component-reuse/   # 组件库复用工作流
│   ├── wk-symbol-reference-scan/ # 全局符号引用扫描
│   ├── wk-review/                # 本地代码修改 Review
│   ├── wk-sync-pb/               # Proto 同步与 ObjC 代码生成
│   ├── wk-lark-wiki/             # API 文档生成、润色与飞书上传
│   ├── wk-crash-repro-fix/       # iOS Crash 闭环排查
│   ├── wk-gh-pr-review-fix/      # GitHub PR review 闭环处理
│   ├── ios-blocked-words-check/  # 禁止关键词检查 Skill
│   └── ios-blocked-words-hook/   # 禁止关键词 PostToolUse Hook
├── install.sh                    # 双目标安装 + curl 远程安装
└── README.md
```

每个 plugin 目录结构：

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json               # Plugin 清单
├── skills/
│   └── plugin-name/
│       ├── SKILL.md              # Skill 主定义
│       ├── references/           # 参考文档（按需）
│       └── scripts/              # 脚本（按需）
├── commands/
│   └── plugin-name.md            # 斜杠命令入口
├── agents/                       # Codex agent 配置（按需）
│   └── openai.yaml
└── hooks/                        # Hook 配置（仅 Hook 类 plugin）
    └── settings-snippet.json
```

## 设计原则

- **独立 Plugin** — 每个 Skill 是独立 plugin，命令以 `/wk-` 前缀区分
- **双目标安装** — 同时安装到 Claude Code 和 Codex
- **证据驱动** — 每个清理建议都附带搜索证据，可验证、可追溯
- **宁可保守** — 不确定时归入"需谨慎确认"，不误删
- **可扩展** — 新增 Skill 只需在 `plugins/` 下添加子目录

## License

MIT
