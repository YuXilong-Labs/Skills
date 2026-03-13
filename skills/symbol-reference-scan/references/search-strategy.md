# 多源搜索策略

> 本文件为 symbol-reference-scan Skill 的搜索策略参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 源码搜索策略

### 搜索文件类型

按优先级排序：

| 优先级 | 文件类型 | 说明 |
|--------|----------|------|
| 高 | `.h`, `.m`, `.mm`, `.swift` | ObjC/Swift 源文件 |
| 高 | `.pch` | 预编译头文件 |
| 中 | `.xib`, `.storyboard` | Interface Builder 文件（XML） |
| 中 | `.plist`, `.pbxproj` | 配置与工程文件 |
| 低 | `.json`, `.strings` | 资源文件 |

### Grep 用法

```bash
# 基本搜索（不区分大小写）
Grep: pattern=<keyword>, path=<project_root>, glob="*.{h,m,mm,swift}", -i=true

# 区分大小写
Grep: pattern=<keyword>, path=<project_root>, glob="*.{h,m,mm,swift}", -i=false

# 获取匹配内容和上下文
Grep: pattern=<keyword>, output_mode="content", -C=2
```

### scope 优先级

当 `scope=source_only` 时只执行源码搜索路径，跳过 Framework 和二进制搜索。

### 排除路径处理

默认排除：`Build`, `DerivedData`, `.git`

排除时使用 Grep 的 glob 机制或在结果中过滤。常见排除目录：

```
Build/
DerivedData/
.git/
*.xcarchive/
```

---

## 2. Framework Headers 搜索策略

### 路径模式

```bash
# CocoaPods 管理的 Framework
<project_root>/Pods/**/*.framework/Headers/*.h
<project_root>/Pods/Headers/**/*.h

# Carthage 管理的 Framework
<project_root>/Carthage/Build/**/*.framework/Headers/*.h

# 手动管理的 Framework
<project_root>/Vendor/**/*.framework/Headers/*.h
<project_root>/Frameworks/**/*.framework/Headers/*.h

# xcframework
<project_root>/**/*.xcframework/**/Headers/*.h
```

### 解析要点

- Header 中的声明通常包含 `@interface`、`@protocol`、`@property`、方法签名
- 注意区分：声明（Header）vs 使用（源码）
- xcframework 可能包含多架构目录（`ios-arm64/`, `ios-arm64_x86_64-simulator/`），同一符号在不同架构 Header 中重复出现需去重

---

## 3. Framework 二进制搜索策略

### 查找二进制文件

```bash
# 查找 .framework 二进制（排除 Headers、Resources 等）
find <project_root> -path "*.framework/*" -type f \
  ! -name "*.h" ! -name "*.plist" ! -name "*.modulemap" \
  ! -name "*.nib" ! -name "*.storyboardc" ! -name "*.car" \
  ! -name "Info.plist" ! -path "*/Headers/*" ! -path "*/_CodeSignature/*" \
  ! -path "*/Modules/*" | head -200
```

验证方式：`file <path>` 确认为 Mach-O 文件。

### strings 用法

```bash
# 带超时保护的 strings 搜索
timeout 30 strings <binary_path> 2>/dev/null | grep -i <keyword> > /tmp/symbol_scan_<hash>.txt

# 查看结果
head -100 /tmp/symbol_scan_<hash>.txt
```

**超时保护：**
- 单次 `strings` 超时 30 秒
- 超时后跳过该二进制，在报告中注明"超时跳过"
- 建议对 >100MB 的二进制优先使用 `nm` 替代

### 符号解析规则

从 `strings` 输出中识别 ObjC 运行时符号：

| 模式 | 含义 | 正则 |
|------|------|------|
| `_OBJC_CLASS_$_ClassName` | 类定义/引用 | `_OBJC_CLASS_\$_\w*<keyword>\w*` |
| `_OBJC_METACLASS_$_ClassName` | 元类 | `_OBJC_METACLASS_\$_\w*<keyword>\w*` |
| `_OBJC_IVAR_$_Class._field` | 实例变量 | `_OBJC_IVAR_\$_\w+\.\w*<keyword>\w*` |
| `-[Class method]` | 实例方法 | `-\[\w*<keyword>\w+ \w+\]` |
| `+[Class method]` | 类方法 | `\+\[\w*<keyword>\w+ \w+\]` |
| `T@"TypeName",*,V_field` | 属性类型编码 | `T@"\w*<keyword>\w*"` |

非 ObjC 运行时格式的匹配归为 `string_constant` 或 `reference`。

### 架构去重

xcframework 包含多架构 slice，同一符号可能在不同架构中重复：

```
MyLib.xcframework/
├── ios-arm64/MyLib.framework/MyLib          # arm64
└── ios-arm64_x86_64-simulator/MyLib.framework/MyLib  # simulator
```

**去重规则：** 同一 xcframework 下，(模块名, 符号名, 符号类型) 相同的条目只保留一条，来源标注为 xcframework 名称（不含架构后缀）。

---

## 4. 静态库搜索策略

### 查找 .a 文件

```bash
find <project_root> -name "*.a" -type f | head -50
```

### strings / nm 用法

```bash
# strings 搜索
timeout 30 strings <lib_path> 2>/dev/null | grep -i <keyword>

# nm 搜索（更精确，仅搜索符号表）
timeout 30 nm <lib_path> 2>/dev/null | grep -i <keyword>
```

`nm` 输出格式：`<address> <type> <symbol_name>`

常见符号类型：
- `T` — 文本段（代码）定义
- `U` — 未定义（外部引用）
- `S` — 数据段符号
- `t` — 本地文本段符号

---

## 5. 业务 vs 三方分类规则

### 业务模块白名单前缀

```
BT*     — 业务模块（BTXxx 前缀）
PLA*    — 平台模块（PLAXxx 前缀）
Pop*    — Poppo 业务模块（PopXxx 前缀）
```

> 以上为默认配置，可根据实际项目调整。

### 三方 SDK 常见前缀

```
AF*     — AFNetworking
SD*     — SDWebImage
MJ*     — MJRefresh / MJExtension
YY*     — YYKit 系列
Masonry / Snap*  — 布局库
FMDB*   — 数据库
React*  — React Native
Flutter*  — Flutter
Google* / GMS* / Firebase* — Google 系
FB*     — Facebook 系
```

### 分类逻辑

1. 从搜索结果中提取模块名（Framework 名称或文件所在目录名）
2. 按白名单前缀匹配：命中 → 业务模块
3. 未命中 → 三方 SDK
4. `include_third_party=false` 时，三方 SDK 结果仅在统计汇总中体现，不列入明细表

---

## 6. 并行执行策略

### 并行度

- **关键词间：** 各关键词搜索可完全并行
- **搜索路径间：** 源码 / Headers / 二进制 三条路径可并行
- **二进制文件间：** 各二进制的 `strings` 命令可并行

### 超时保护

| 操作 | 超时 | 超时处理 |
|------|------|----------|
| 单个 `strings` 命令 | 30s | 跳过，标记"超时" |
| 单个 `nm` 命令 | 30s | 跳过，标记"超时" |
| `find` 查找二进制 | 60s | 使用已找到的结果继续 |
| 整体扫描 | 无硬限制 | 依赖单步超时保护 |

### 输出重定向

所有大输出命令必须重定向到临时文件：

```bash
# strings 输出重定向
timeout 30 strings <binary> 2>/dev/null | grep -i <keyword> > /tmp/symbol_scan_XXXX.txt

# 仅展示摘要
wc -l /tmp/symbol_scan_XXXX.txt   # 匹配行数
head -20 /tmp/symbol_scan_XXXX.txt  # 前 20 行预览
```
