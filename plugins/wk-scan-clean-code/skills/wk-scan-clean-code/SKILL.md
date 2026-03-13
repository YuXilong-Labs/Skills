---
name: wk-scan-clean-code
description: |
  iOS/macOS 代码清理审计工具 — 识别 ObjC/Swift 工程中可安全删除的字段、方法、文件。
  支持 4 种扫描模式：Model 字段审计、死代码检测、无用文件检测、全量扫描。
  所有结论附带证据链，分级输出，宁可保守不误删。
---

# Scan Clean Code — 代码清理审计 Skill

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `target_file` | 否 | — | 待审计的目标文件路径（单文件模式） |
| `project_root` | 是 | `.` | 工程根目录（搜索范围） |
| `business_scope` | 否 | `project_root` | 业务代码目录（排除 Pods/Vendor） |
| `exclude_paths` | 否 | `Pods,Vendor,ThirdParty,Carthage,Build,DerivedData` | 逗号分隔的排除路径 |
| `language` | 否 | 自动检测 | `objc` / `swift` / `auto` |
| `mode` | 否 | `model-fields` | 扫描模式，见下方说明 |

## 扫描模式

### 1. `model-fields` — Model 字段审计

针对单个 Model 文件，逐字段检查是否仍被业务代码使用。

**适用场景：** 清理膨胀的 Model 类、API 返回字段瘦身、删除历史遗留字段。

**工作流：**
1. 解析目标文件，提取所有字段（属性 + 成员变量）
2. 对每个字段，在 `business_scope` 内搜索所有引用
3. 排除自身文件内的声明/赋值/初始化
4. 分析剩余引用是否为活跃业务代码
5. 输出分类报告

> 详细搜索模式见 [objc-model-field-audit.md](references/objc-model-field-audit.md) 和 [swift-model-field-audit.md](references/swift-model-field-audit.md)

### 2. `dead-code` — 死代码检测

扫描指定范围内的无入口方法、废弃页面、不可达代码。

**适用场景：** 版本迭代后清理废弃功能、下线旧入口、精简代码体积。

**工作流：**
1. 盘点目标范围内所有方法/函数声明
2. 搜索每个方法的调用点
3. 识别断裂调用链（调用者本身也是死代码）
4. 检查动态调用可能性（@selector、performSelector、NSStringFromSelector）
5. 输出分类报告

> 详细规则见 [dead-code-detection.md](references/dead-code-detection.md)

### 3. `unused-files` — 无用文件检测

识别工程中不再被引用的源文件、资源文件。

**适用场景：** 工程瘦包、清理历史模块、删除孤立文件。

**工作流：**
1. 盘点目标范围内所有文件（按类型分组）
2. 对每个文件，搜索 import/include 引用
3. 交叉检查 .pbxproj 编译源列表
4. 检查 xib/storyboard 中的 customClass 引用
5. 输出分类报告

> 详细规则见 [unused-file-detection.md](references/unused-file-detection.md)

### 4. `full` — 全量扫描

依次执行 model-fields + dead-code + unused-files，输出综合报告。

**适用场景：** 大版本清理、技术债务治理、模块重构前的全面评估。

---

## 核心工作流

无论哪种模式，都遵循统一的 5 步流程：

```
盘点 → 引用搜索 → 分类 → 证据收集 → 报告
```

### Step 1: 盘点（Inventory）

根据模式提取待审计的目标列表：
- `model-fields`：解析属性声明、@property、var/let、成员变量
- `dead-code`：解析方法/函数签名
- `unused-files`：列出所有源文件和资源文件

### Step 2: 引用搜索（Reference Search）

对每个目标，使用 Grep 在 `business_scope` 内搜索引用：
- 排除 `exclude_paths` 中的目录
- 排除目标自身文件中的声明行
- 使用语言特定的搜索模式（见 References）

**搜索原则：**
- 宁多搜不漏搜 — 对每种可能的引用方式都要检查
- ObjC 动态特性要特别注意 — KVC、@selector、performSelector、NSStringFromSelector
- 字符串化引用必查 — NSDictionary 字面量、JSON 映射、埋点字典

### Step 3: 分类（Classification）

根据搜索结果将每个目标归入三类：

| 分类 | 标准 | 操作建议 |
|------|------|----------|
| **活跃使用** | 存在 ≥1 处活跃业务引用 | 保留，不动 |
| **可清理** | 无活跃引用，或仅被死代码引用 | 可安全删除（需二次确认） |
| **需谨慎确认** | 存在动态调用、反射、字符串引用可能性 | 人工确认后决定 |

**置信度细分：**

- **可清理 — 高置信度：** 全项目零引用，且不涉及动态调用模式
- **可清理 — 中置信度：** 仅被已确认的死代码引用，或引用极少且在废弃模块中

### Step 4: 证据收集（Evidence）

为每个"可清理"和"需谨慎确认"的目标收集证据：
- 搜索命令及结果（grep pattern + 匹配行）
- 引用位置列表（file:line）
- 引用者的活跃状态（引用者是否也是死代码）
- 动态调用风险评估

### Step 5: 报告（Report）

输出结构化报告，格式见 [output-format.md](references/output-format.md)。

---

## ObjC/Swift 搜索模式速查

### ObjC 字段引用搜索清单

```
# 1. 点语法访问
self.fieldName / obj.fieldName / _fieldName

# 2. 方括号消息发送
[self fieldName] / [self setFieldName:]

# 3. KVC/KVO
@"fieldName" / NSStringFromSelector(@selector(fieldName))
valueForKey: / setValue:forKey: / valueForKeyPath:

# 4. JSON 映射框架
YYModel: + modelCustomPropertyMapper
MJExtension: + mj_replacedKeyFromPropertyName
Mantle: + JSONKeyPathsByPropertyKey

# 5. NSCoding 归档
encodeObject:forKey:@"fieldName" / decodeObjectForKey:@"fieldName"

# 6. 数据库映射
FMDB: objectForColumnName:@"fieldName"
WCDB: WCDB_SYNTHESIZE(ClassName, fieldName)

# 7. @selector 引用
@selector(fieldName) / @selector(setFieldName:)

# 8. IBOutlet / IBAction
Interface Builder 连接（检查 xib/storyboard XML）

# 9. 埋点/字典字面量
@{@"fieldName": self.fieldName}
```

### Swift 字段引用搜索清单

```
# 1. 直接访问
self.fieldName / instance.fieldName

# 2. CodingKeys 枚举
case fieldName = "json_key"

# 3. KeyPath
\ClassName.fieldName / \.fieldName

# 4. Mirror 反射
Mirror(reflecting: self) — 无法静态分析，标记需谨慎确认

# 5. #selector
#selector(getter: ClassName.fieldName)

# 6. @objc dynamic
标记为 @objc 或 dynamic 的属性需检查 ObjC 调用侧

# 7. 属性包装器
@Published / @State / @Binding / @AppStorage 等
```

---

## 安全规则

> ⚠️ 以下规则优先级最高，任何分类逻辑都不得违反。

1. **宁可误报不漏报** — 不确定是否被使用时，归入"需谨慎确认"
2. **动态调用保守处理** — 涉及 KVC、@selector、performSelector、NSStringFromSelector 的字段默认归入"需谨慎确认"
3. **协议/父类属性保守处理** — 如果字段是协议要求或父类声明，即使当前类未使用也标记为"需谨慎确认"
4. **跨模块引用要查全** — 搜索范围必须覆盖整个 `project_root`（排除 exclude_paths 后）
5. **不自动执行删除** — Skill 只输出报告，不修改任何源文件
6. **证据链完整** — 每个"可清理"结论都必须附带搜索证据（用了什么 pattern、搜了哪些目录、结果是什么）
7. **区分声明与使用** — 字段在自身文件中的 @property 声明、@synthesize、init 赋值不算"使用"
8. **递归死代码检测** — 如果引用者本身也是死代码，该引用不算活跃引用

---

## 输出格式

报告使用 Markdown 格式，包含以下部分：
1. 审计概要（目标、范围、模式、时间）
2. 统计汇总（总数、各分类数量、清理率）
3. 可清理项明细（逐项列出证据）
4. 需谨慎确认项明细
5. 活跃使用项列表（简要）

> 完整格式模板见 [output-format.md](references/output-format.md)
