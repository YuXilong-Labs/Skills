# Skills — Claude Code 技能仓库

面向 iOS/macOS 开发的 Claude Code Skills 集合。

## 可用 Skills

### wk-scan-clean-code

代码清理审计工具 — 识别 ObjC/Swift 工程中可安全删除的字段、方法、文件。

**功能：**
- **Model 字段审计** — 逐字段检查是否仍被业务代码使用
- **死代码检测** — 识别无入口方法、废弃页面、断裂调用链
- **无用文件检测** — 找出未被引用的源文件和资源文件
- **全量扫描** — 综合执行以上三种检测

**特点：**
- 支持 Objective-C 和 Swift
- 所有结论附带完整证据链（搜索 pattern + 匹配结果）
- 三级分类：可清理（高/中置信度）、需谨慎确认、活跃使用
- ObjC 动态特性感知（KVC、@selector、JSON 映射框架等）
- 只输出报告，不自动修改代码

### wk-ios-component-reuse

iOS 组件库复用工作流 — 选型、实现、审查、迁移阶段强制执行"先检索组件再行动"。

**前置要求：** MCP `ios-components` server 已连接。

**4 种模式：**
- **selection** — 组件选型评估，输出候选矩阵与主/备方案
- **implementation** — 复用优先实现，先检索再编码（默认模式）
- **review** — PR 组件复用审查，输出证据链与严重级别
- **migration** — 重复实现迁移，输出映射表与分批改造计划

**特点：**
- JSON-first 多轮检索策略，小步收敛
- 所有结论必须附带证据最小集（检索 + API + 佐证）
- 完整的失败恢复与回退路径
- 结构化输出契约，可审计、可追溯

### wk-symbol-reference-scan

iOS 工程全局符号引用扫描工具 — 覆盖源码、Framework Headers、二进制 strings，输出结构化报告。

**功能：**
- **单关键词扫描** — 快速确认某个符号在工程中的使用情况
- **批量扫描** — 多关键词逐一扫描，附加综合关联关系分析
- **关联扫描** — 自动扩展相关符号变体后批量扫描

**特点：**
- 三条并行搜索路径：源码 Grep、Framework Headers、二进制 strings
- ObjC 运行时符号分类（class/property/method/ivar 等）
- 业务模块 vs 三方 SDK 自动分类
- 四元组去重（模块, 类, 符号名, 符号类型）
- 只读操作，不修改任何文件
- strings 超时保护（30s/次）

### ios-blocked-words-check

iOS App Store 审核合规禁止关键词检查 — 智能匹配敏感词（赌博、支付、金融等），防止代码提交后被拒审。

**功能：**
- **三种匹配模式** — `compound`（复合标识符组件）、`exact`（完整 token）、`word_boundary`（单词边界）
- **智能防误判** — `payload` 不误报 `pay`、`window` 不误报 `win`、`cache` 不误报 `cash`
- **多种检查方式** — 指定文件、git staged 文件、全目录扫描
- **内置白名单** — 覆盖常见 iOS/protobuf 框架词汇

**特点：**
- 覆盖 60+ App Store 高危词
- 驼峰/下划线语义边界智能识别
- JSON 输出格式，可集成到 CI/CD
- 纯 Python 实现，零依赖

### ios-blocked-words-hook

iOS 禁止关键词 PostToolUse Hook — Edit/Write iOS 文件后自动触发关键词检查。

**功能：**
- **自动触发** — Edit/Write iOS 源码文件后自动运行检查
- **非阻塞** — 不阻止编辑操作，仅注入警告到 Claude 上下文
- **智能过滤** — 非 iOS 文件自动跳过
- **禁止提交** — 发现违规时提示禁止 git commit

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
/plugin install ios-blocked-words-check@yuxilong-skills
/plugin install ios-blocked-words-hook@yuxilong-skills
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
./install.sh ios-blocked-words-check
./install.sh ios-blocked-words-hook
```

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
/ios-blocked-words-check 帮我检查 SendGift.pbobjc.m 里有没有敏感词
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
├── plugins/                      # 每个 Skill 独立为一个 plugin
│   ├── wk-scan-clean-code/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── skills/
│   │   │   └── wk-scan-clean-code/
│   │   │       ├── SKILL.md
│   │   │       └── references/
│   │   └── commands/
│   │       └── wk-scan-clean-code.md
│   ├── wk-ios-component-reuse/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── skills/
│   │   │   └── wk-ios-component-reuse/
│   │   │       ├── SKILL.md
│   │   │       └── references/
│   │   └── commands/
│   │       └── wk-ios-component-reuse.md
│   └── wk-symbol-reference-scan/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── skills/
│       │   └── wk-symbol-reference-scan/
│       │       ├── SKILL.md
│       │       └── references/
│       ├── commands/
│       │   └── wk-symbol-reference-scan.md
│       └── README.md
│   ├── ios-blocked-words-check/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── skills/
│   │   │   └── ios-blocked-words-check/
│   │   │       ├── SKILL.md
│   │   │       └── scripts/
│   │   │           └── check_blocked_words.py
│   │   ├── commands/
│   │   │   └── ios-blocked-words-check.md
│   │   └── README.md
│   └── ios-blocked-words-hook/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── hooks/
│       │   └── settings-snippet.json
│       └── README.md
├── install.sh                    # 双目标安装 + curl 远程安装
└── README.md
```

## 设计原则

- **独立 Plugin** — 每个 Skill 是独立 plugin，命令以 `/wk-` 前缀区分
- **双目标安装** — 同时安装到 Claude Code 和 Codex
- **证据驱动** — 每个清理建议都附带搜索证据，可验证、可追溯
- **宁可保守** — 不确定时归入"需谨慎确认"，不误删
- **可扩展** — 新增 Skill 只需在 `plugins/` 下添加子目录

## License

MIT
