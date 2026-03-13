# Skills — Claude Code 技能仓库

面向 iOS/macOS 开发的 Claude Code Skills 集合。

## 可用 Skills

### scan-clean-code

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

### ios-component-reuse

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

## 安装

### 方式 1：Plugin Marketplace（推荐）

> 需要 Claude Code ≥ 1.0.33

```
# 添加 marketplace
/plugin marketplace add YuXilong-Labs/Skills

# 安装 plugin
/plugin install scan-clean-code@yuxilong-skills
/plugin install ios-component-reuse@yuxilong-skills
```

### 方式 2：手动安装

```bash
# 克隆仓库
git clone https://github.com/YuXilong-Labs/Skills.git
cd Skills

# 安装所有 Skills
./install.sh

# 安装指定 Skill
./install.sh scan-clean-code
./install.sh ios-component-reuse
```

## 使用

安装后在 Claude Code 中使用：

```
# scan-clean-code
/scan-clean-code target_file=Models/UserModel.h mode=model-fields
/scan-clean-code project_root=. mode=dead-code
/scan-clean-code project_root=. mode=unused-files
/scan-clean-code project_root=. mode=full

# ios-component-reuse
/ios-component-reuse mode=selection requirement=做一个带分页列表的页面
/ios-component-reuse mode=implementation requirement=实现头像圆角缓存加载
/ios-component-reuse mode=review requirement=检查PR是否有自定义图片下载器
/ios-component-reuse mode=migration requirement=把自定义缓存迁移到基础组件
```

也支持自然语言：

```
/scan-clean-code 帮我检查 UserModel.h 里哪些字段没用了
/ios-component-reuse 实现上传功能，不要重复造轮子
```

## 管理

```bash
# 列出所有可用 Skills
./install.sh --list

# 卸载指定 Skill
./install.sh --uninstall scan-clean-code
```

## 目录结构

```
Skills/
├── .claude-plugin/         # Plugin Marketplace 清单
│   ├── plugin.json
│   └── marketplace.json
├── install.sh              # 手动安装脚本
├── skills/                 # 镜像 ~/.claude/skills/
│   ├── scan-clean-code/
│   │   ├── SKILL.md
│   │   └── references/
│   └── ios-component-reuse/
│       ├── SKILL.md
│       └── references/
└── commands/               # 镜像 ~/.claude/commands/
    ├── scan-clean-code.md
    └── ios-component-reuse.md
```

## 设计原则

- **复用优先** — 安装时直接映射到 `~/.claude/` 目录结构
- **证据驱动** — 每个清理建议都附带搜索证据，可验证、可追溯
- **宁可保守** — 不确定时归入"需谨慎确认"，不误删
- **可扩展** — 新增 Skill 只需添加 `skills/<name>/` + `commands/<name>.md`

## License

MIT
