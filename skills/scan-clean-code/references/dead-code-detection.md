# 死代码检测模式

> 本文件为 scan-clean-code Skill 的死代码检测参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 检测范围

### 1.1 无入口方法

**定义：** 已声明但在整个工程中无任何调用点的方法/函数。

#### ObjC 方法提取

```bash
# 实例方法
^-\s*\([^)]+\)\s*\w+
# 类方法
^\+\s*\([^)]+\)\s*\w+
```

#### Swift 函数提取

```bash
# 函数/方法声明
\bfunc\s+\w+
# 可能需要考虑访问控制
(public|open|internal|fileprivate|private)\s+func\s+\w+
```

#### 引用搜索

```bash
# ObjC：搜索方法名（selector 风格）
\bmethodName\b
\bmethodName:
\[.*\bmethodName\b
@selector\(methodName\)

# Swift：搜索函数名
\.methodName\(
\.methodName\s*\{   # trailing closure
```

#### 排除（不应标记为死代码）

- `viewDidLoad`、`viewWillAppear` 等 UIKit 生命周期方法
- `init` 系列方法（`initWithFrame:`、`initWithCoder:` 等）
- `dealloc` / `deinit`
- `layoutSubviews`、`drawRect:`、`draw(_:)`
- 协议/代理要求的方法
- `IBAction` 标记的方法
- `@objc` 标记的方法（可能被 ObjC 运行时调用）
- `override` 方法（父类可能通过多态调用）
- `applicationDidFinishLaunching:` 等 AppDelegate 方法
- `main` 函数
- 单元测试方法（`test` 开头的方法 + XCTestCase 子类）

### 1.2 废弃页面 / 控制器

**定义：** UIViewController / NSViewController 子类，在工程中无任何创建和跳转入口。

搜索策略：
```bash
# 类名出现的地方
\bMyViewController\b
# alloc init / new
\[\[MyViewController\s+alloc\]\s+init
\[MyViewController\s+new\]
# Swift 初始化
MyViewController\(
# Storyboard 实例化
instantiateViewController.*"MyViewControllerID"
# 路由注册
registerClass.*MyViewController
# push / present
push.*MyViewController
present.*MyViewController
```

同时检查：
- `Main.storyboard` 中是否被引用为 `customClass`
- Router/Navigator 配置文件中是否注册

### 1.3 不可达分支

**定义：** 条件永远为 false 的分支、永远不会执行到的 else 块。

常见模式：
```objc
// 宏控制的编译分支（已过期的 feature flag）
#if 0
  // dead code
#endif

// 永假条件
if (NO) { ... }
if (false) { ... }

// 注释掉但未删除的代码块
// [self doSomething];
```

> ⚠️ 不可达分支检测主要依赖模式匹配，准确率有限。仅报告高置信度的情况。

### 1.4 断裂调用链

**定义：** 方法 A 调用方法 B，但方法 A 本身也是死代码，则方法 B 的引用不算活跃。

检测流程：
1. 找到方法 B 的所有调用点
2. 对每个调用者，递归检查调用者是否有活跃入口
3. 如果所有调用者都是死代码，则方法 B 也是死代码

**递归深度限制：** 最多递归 3 层，超过 3 层标记为"需谨慎确认"。

### 1.5 死 Category / Extension

**定义：** Category 或 Extension 中的所有方法都无外部调用。

```bash
# ObjC Category
@interface\s+\w+\s*\(\w+\)
@implementation\s+\w+\s*\(\w+\)

# Swift Extension
extension\s+\w+
```

如果 Category/Extension 中所有方法都判定为死代码，则整个 Category/Extension 可能可以删除。

### 1.6 未使用的协议/代理

```bash
# ObjC 协议声明
@protocol\s+(\w+)
# Swift 协议声明
protocol\s+(\w+)
```

搜索协议名的引用：
```bash
# 遵循声明
<ProtocolName>         # ObjC
:\s*.*ProtocolName     # Swift
# 变量类型
id<ProtocolName>       # ObjC
\bProtocolName\b       # Swift 类型引用
```

如果协议无遵循者且无类型引用，可标记为可清理。

---

## 2. ObjC 动态调用风险

以下模式表示方法可能被动态调用，不应简单判定为死代码：

```bash
# performSelector 系列
performSelector:@selector(methodName)
performSelector:NSSelectorFromString(@"methodName")
objc_msgSend\(.*"methodName"

# 响应检查
respondsToSelector:@selector(methodName)

# 通知处理
@selector(methodName).*addObserver
addObserver.*@selector(methodName)

# Target-Action
addTarget.*@selector(methodName)
```

如果方法通过字符串动态构造 selector 调用，无法静态分析，标记"需谨慎确认"。

---

## 3. 测试 / Demo 代码识别

以下代码应在统计中**单独列出**，不混入业务死代码：

| 类型 | 识别规则 |
|------|----------|
| 单元测试 | 文件路径包含 `Tests/`、`Test/`、`Specs/`；类继承 `XCTestCase` |
| UI 测试 | 文件路径包含 `UITests/`；类继承 `XCUITestCase` |
| Demo / Example | 文件路径包含 `Demo/`、`Example/`、`Sample/` |
| Playground | `.playground` 文件 |
| 调试代码 | `#if DEBUG` 块内的代码 |

---

## 4. 输出字段

每个死代码项应包含：

| 字段 | 说明 |
|------|------|
| 类型 | method / function / class / protocol / category / extension |
| 名称 | 完整签名 |
| 文件 | 定义所在文件路径 |
| 行号 | 定义所在行 |
| 分类 | 可清理（高/中置信度） / 需谨慎确认 |
| 原因 | 简要说明为什么判定为死代码 |
| 调用链 | 如果是断裂调用链，列出调用关系 |
| 风险 | 动态调用风险说明（如有） |
