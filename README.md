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

## 安装

```bash
# 克隆仓库
git clone https://github.com/YuXilong-Labs/Skills.git
cd Skills

# 安装所有 Skills
./install.sh

# 安装指定 Skill
./install.sh scan-clean-code
```

## 使用

安装后在 Claude Code 中使用：

```
/scan-clean-code target_file=Models/UserModel.h mode=model-fields
/scan-clean-code project_root=. mode=dead-code
/scan-clean-code project_root=. mode=unused-files
/scan-clean-code project_root=. mode=full
```

也支持自然语言：

```
/scan-clean-code 帮我检查 UserModel.h 里哪些字段没用了
/scan-clean-code 扫描 Sources 目录下的死代码
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
├── install.sh              # 统一安装脚本
├── skills/                 # 镜像 ~/.claude/skills/
│   └── scan-clean-code/
│       ├── SKILL.md        # 主技能定义
│       └── references/     # 参考文档
└── commands/               # 镜像 ~/.claude/commands/
    └── scan-clean-code.md  # 命令入口
```

## 设计原则

- **复用优先** — 安装时直接映射到 `~/.claude/` 目录结构
- **证据驱动** — 每个清理建议都附带搜索证据，可验证、可追溯
- **宁可保守** — 不确定时归入"需谨慎确认"，不误删
- **可扩展** — 新增 Skill 只需添加 `skills/<name>/` + `commands/<name>.md`

## License

MIT
