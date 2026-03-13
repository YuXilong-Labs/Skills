# ObjC Model 字段审计指南

> 本文件为 scan-clean-code Skill 的 ObjC 字段审计参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 字段提取

### 1.1 @property 声明

```
# 匹配 @property 行，提取属性名
@property\s*\([^)]*\)\s*\w+[\s*]*\w+\s*;
```

提取规则：
- 取最后一个标识符（分号前）作为属性名
- 注意指针类型：`NSString *name` → 属性名为 `name`
- 注意 block 类型：`void (^completion)(void)` → 属性名为 `completion`

### 1.2 成员变量（@interface / @implementation 的 {} 内）

```
# 匹配花括号内的成员变量声明
^\s+\w+[\s*]*_?\w+\s*;
```

提取规则：
- 通常以下划线开头（`_fieldName`）
- 与同名 @property 对应时视为同一字段

### 1.3 @synthesize

```
@synthesize fieldName = _fieldName;
```

建立属性名与成员变量名的映射关系。

---

## 2. 引用搜索清单（逐项检查）

### 2.1 点语法访问

```bash
# Grep pattern（在 business_scope 内搜索）
\.fieldName\b
```

注意排除：
- 自身文件中的 @property 声明行
- 注释行（`//` 和 `/* */`）
- 字符串字面量中的误匹配

### 2.2 方括号消息发送（getter/setter）

```bash
# getter
\[[\w\s\.]+\bfieldName\]
# setter（setFieldName: 首字母大写）
\bsetFieldName:
```

### 2.3 下划线直接访问（成员变量）

```bash
# 搜索 _fieldName（注意区分前缀重名）
\b_fieldName\b
```

排除：
- @synthesize 行
- 自身 init / dealloc 中的赋值

### 2.4 KVC / KVO

```bash
# valueForKey / setValue:forKey 系列
@"fieldName"
# NSStringFromSelector
NSStringFromSelector\(\s*@selector\(\s*fieldName\s*\)\s*\)
# KVO observe
addObserver.*forKeyPath.*@"fieldName"
```

**⚠️ 如果发现 KVC/KVO 引用，该字段应归入"需谨慎确认"。**

### 2.5 JSON 映射框架

#### YYModel

```bash
# + modelCustomPropertyMapper 方法内
@"fieldName"\s*:\s*@"
# 或反向映射
:\s*@"fieldName"
```

#### MJExtension

```bash
# + mj_replacedKeyFromPropertyName 方法内
@"fieldName"\s*:\s*@"
```

#### Mantle

```bash
# + JSONKeyPathsByPropertyKey 方法内
@"fieldName"\s*:
# NSStringFromSelector 形式
NSStringFromSelector\(@selector\(fieldName\)\)
```

**搜索策略：** 在目标 Model 文件本身中搜索 `modelCustomPropertyMapper`、`mj_replacedKeyFromPropertyName`、`JSONKeyPathsByPropertyKey` 方法，解析其中的字段映射关系。如果某字段出现在映射中，即使外部无直接引用，也说明该字段由 JSON 反序列化赋值，需检查 JSON 数据消费侧。

### 2.6 NSCoding 归档

```bash
# encodeObject:forKey:
encodeObject:.*forKey:@"fieldName"
encode\w+:.*forKey:@"fieldName"
# decodeObjectForKey:
decodeObjectForKey:@"fieldName"
decode\w+ForKey:@"fieldName"
```

如果 Model 实现了 `<NSCoding>` / `<NSSecureCoding>`，检查 `encodeWithCoder:` 和 `initWithCoder:` 方法。

### 2.7 数据库映射

#### FMDB

```bash
# 从 FMResultSet 取值
objectForColumnName:@"fieldName"
\w+ForColumnName:@"fieldName"
objectForColumn:@"fieldName"
\bfieldName\b.*FROM\b   # SQL 语句中的列名
```

#### WCDB

```bash
WCDB_SYNTHESIZE\(\w+,\s*fieldName\)
WCDB_PRIMARY\(\w+,\s*fieldName\)
WCDB_INDEX\(\w+,.*fieldName\)
```

### 2.8 @selector 引用

```bash
@selector\(\s*fieldName\s*\)
@selector\(\s*setFieldName:\s*\)
NSSelectorFromString\(@"fieldName"\)
NSSelectorFromString\(@"setFieldName:"\)
```

### 2.9 Interface Builder 连接

在 .xib 和 .storyboard 文件中搜索：

```bash
# IBOutlet 连接
property="fieldName"
# IBAction 连接
selector="fieldName:"
```

### 2.10 埋点 / 字典字面量

```bash
# NSDictionary 字面量中的 key
@"fieldName"\s*:
# 或作为 value
:\s*\w+\.fieldName
:\s*_fieldName
```

### 2.11 Predicate / 排序描述

```bash
# NSPredicate
predicateWithFormat:.*\bfieldName\b
# NSSortDescriptor
sortDescriptorWithKey:@"fieldName"
```

---

## 3. 声明 vs 使用的区分

以下引用**不算**业务使用，应从引用计数中排除：

| 类型 | 示例 |
|------|------|
| @property 声明 | `@property (nonatomic, copy) NSString *fieldName;` |
| @synthesize | `@synthesize fieldName = _fieldName;` |
| 成员变量声明 | `NSString *_fieldName;` |
| init 中的默认赋值 | `_fieldName = @"default";`（仅在 init 系列方法中） |
| dealloc 中的置空 | `_fieldName = nil;` |
| @dynamic 声明 | `@dynamic fieldName;` |
| 注释中的引用 | `// fieldName is used for...` |

---

## 4. ObjC 特有风险

| 风险 | 说明 | 处理 |
|------|------|------|
| 动态消息派发 | `performSelector:` 可在运行时调用任意方法 | 搜索 `performSelector` + `NSSelectorFromString` |
| 关联对象 | `objc_setAssociatedObject` 可动态添加属性 | 通常不影响静态声明字段 |
| Runtime 反射 | `class_getProperty` / `property_getName` | 标记为"需谨慎确认" |
| 宏展开 | 字段名可能通过宏生成 | 检查相关宏定义 |
| Category 重写 | Category 可能覆盖 getter/setter | 搜索同名 Category 方法 |
