# Swift Model 字段审计指南

> 本文件为 scan-clean-code Skill 的 Swift 字段审计参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 字段提取

### 1.1 存储属性

```swift
// var / let 声明
var fieldName: Type
let fieldName: Type
var fieldName: Type = defaultValue
lazy var fieldName: Type = { ... }()
```

提取 pattern：
```
\b(var|let)\s+(\w+)\s*:\s*
```

### 1.2 计算属性

```swift
var fieldName: Type {
    get { ... }
    set { ... }
}
```

计算属性通常依赖其他存储属性，审计时需注意：
- 计算属性本身如果无外部引用，可清理
- 但其内部依赖的存储属性可能仍有其他引用

### 1.3 属性包装器

```swift
@Published var fieldName: Type
@State var fieldName: Type
@Binding var fieldName: Type
@AppStorage("key") var fieldName: Type
@ObservedObject var fieldName: Type
@EnvironmentObject var fieldName: Type
```

属性包装器生成的辅助属性（如 `$fieldName`、`_fieldName`）也需纳入搜索。

### 1.4 static / class 属性

```swift
static var fieldName: Type
static let fieldName: Type
class var fieldName: Type
```

---

## 2. 引用搜索清单

### 2.1 直接访问

```bash
# 点语法
\.fieldName\b
# self 访问
self\.fieldName\b
```

排除规则同 ObjC：注释行、字符串字面量、自身声明行。

### 2.2 CodingKeys 枚举

```bash
# 在目标文件内搜索 CodingKeys
case fieldName
case fieldName\s*=\s*"
```

如果字段出现在 CodingKeys 中：
- 说明参与 JSON 编解码
- 即使无直接访问，也可能由 Codable 自动合成使用
- 需检查数据消费侧

### 2.3 KeyPath 引用

```bash
# 完整 KeyPath
\\ClassName\.fieldName
# 简写 KeyPath
\\\.fieldName
# 动态 KeyPath
#keyPath\(.*fieldName\)
```

### 2.4 Mirror 反射

```bash
Mirror\(reflecting:
```

**⚠️ 如果目标类型被 Mirror 反射使用，所有字段应标记为"需谨慎确认"。**
Mirror 会枚举所有存储属性，无法静态确定哪些字段被使用。

### 2.5 #selector 引用

```bash
#selector\(.*fieldName.*\)
#selector\(getter:\s*\w+\.fieldName\)
#selector\(setter:\s*\w+\.fieldName\)
```

### 2.6 @objc / dynamic 标记

如果属性标记了 `@objc` 或 `dynamic`：
- 可能被 ObjC 代码调用 → 需在 .m/.mm 文件中搜索
- 可能被 KVC/KVO 使用 → 搜索 `value(forKey:)` / `setValue(_:forKey:)`
- 标记为"需谨慎确认"

```bash
# 搜索 KVC 使用
value\(forKey:\s*"fieldName"\)
setValue\(.*forKey:\s*"fieldName"\)
value\(forKeyPath:\s*".*fieldName.*"\)
```

### 2.7 Codable 自动合成

如果类型遵循 Codable/Decodable/Encodable 且未显式实现 `init(from:)` / `encode(to:)`：
- 编译器自动合成编解码逻辑，所有存储属性参与
- 此时字段即使无直接引用，也可能通过 JSON 编解码被使用
- 需检查该 Model 的使用场景，判断哪些字段真正被消费

### 2.8 SwiftUI 数据流

```bash
# 属性包装器投影值
\$fieldName\b
# 环境值
@Environment\(\.fieldName\)
```

### 2.9 属性包装器辅助属性

```bash
# _ 前缀（包装器存储）
\b_fieldName\b
# $ 前缀（投影值）
\$fieldName\b
```

### 2.10 Combine / async 链式引用

```bash
# Combine publisher
\.\$fieldName\s*\.
# map/compactMap 中的 KeyPath
\.map\(\s*\\\.fieldName\s*\)
\.compactMap\(\s*\\\.fieldName\s*\)
```

---

## 3. 声明 vs 使用的区分

以下引用**不算**业务使用：

| 类型 | 示例 |
|------|------|
| 属性声明 | `var fieldName: String` |
| 默认值赋值 | `var fieldName: String = ""` |
| init 中的参数赋值 | `self.fieldName = fieldName`（init 参数传入） |
| CodingKeys case 声明 | `case fieldName = "key"`（声明本身不算，需看是否被编解码使用） |
| 注释中的引用 | `// fieldName stores the user name` |
| 字符串插值中的键名 | `print("fieldName: \(self.fieldName)")` 中 `fieldName:` 不算 |

---

## 4. Swift 特有风险

| 风险 | 说明 | 处理 |
|------|------|------|
| 协议要求 | 属性可能是协议声明的一部分 | 检查协议定义，标记"需谨慎确认" |
| 泛型约束 | 属性可能通过泛型约束被间接使用 | 搜索 where 子句 |
| @dynamicMemberLookup | 属性可能通过下标语法动态访问 | 标记"需谨慎确认" |
| 属性观察者 | `willSet` / `didSet` 内可能有副作用 | 检查观察者内的逻辑 |
| Result Builder | 属性可能在 @ViewBuilder 等中被隐式使用 | 搜索 body / content 闭包 |
| Macro 展开 | Swift Macro 可能生成引用 | 检查相关宏定义 |
| 跨模块可见性 | `public` / `open` 属性可能被其他模块使用 | 扩大搜索范围到所有依赖模块 |
