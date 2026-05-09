---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Simplicity Rules

> 本文件与 [coding-style.md](./coding-style.md) 并列，专门约束实现复杂度与函数内逻辑注释规范。
> 闭包简洁性规范见 [coding-style.md Closure Simplicity](./coding-style.md#closure-simplicity)。

## Core Principles

### Simplicity First — 优先最简实现

**实现前必须先想最简方案**，只有在最简方案确实无法满足需求时，才允许引入更复杂的结构。禁止为了"看起来更工程化"而增加不必要的层次。

```swift
// CORRECT — 直接 for-in 累加，意图清晰
var total = 0
for item in items {
    total += item.price
}

// WRONG — 为简单求和提前抽 Strategy 协议 + 工厂，过度设计
protocol AggregationStrategy {
    func aggregate(_ items: [Item]) -> Int
}
let strategy = AggregationStrategyFactory.make(type: .sum)
let total = strategy.aggregate(items)
```

### YAGNI — 禁止过度抽象

禁止为"将来可能的扩展"提前引入协议、泛型、`associatedtype`、PAT（Protocol with Associated Type）。当前只有一个实现时，**必须**直接写实现类型，不得提前抽协议。

```swift
// CORRECT — 当前只有一种数据源，直接实现
final class UserDataSource {
    func fetchUsers() -> [UserModel] { ... }
}

// WRONG — 只有一个实现却提前抽协议 + 泛型，增加无谓的间接层
protocol DataSourceProtocol {
    associatedtype Item
    func fetchItems() -> [Item]
}
final class UserDataSource: DataSourceProtocol {
    func fetchItems() -> [UserModel] { ... }
}
```

### 禁止过度封装

禁止为单一调用点抽取 helper 方法；禁止为简单类型包装 wrapper 类型。封装必须有明确的复用价值（≥ 2 个调用点，或逻辑行数 > 10 行 / 圈复杂度 > 3）。

```swift
// CORRECT — 3 行逻辑直接写在调用处，无需封装
let displayName = user.nickname.isEmpty ? user.uid : user.nickname
label.text = displayName
label.isHidden = displayName.isEmpty

// WRONG — 只被调用一次的私有 helper，增加跳转成本
private func configureDisplayNameLabel() {
    let displayName = user.nickname.isEmpty ? user.uid : user.nickname
    label.text = displayName
    label.isHidden = displayName.isEmpty
}
```

## Quantitative Constraints — 量化硬性阈值

| 维度 | 上限 | 超出后的处理方式 |
|------|------|-----------------|
| 条件/循环嵌套深度 | 3 层 | 用 `guard` / early return 或提取方法消除嵌套 |
| 单函数/方法行数 | 40 行 | 拆分为多个职责单一的方法 |
| 单文件行数 | 400 行 | 拆分为多个文件，每文件一个主类型 |
| 圈复杂度 | 10 | 提取方法或简化分支逻辑 |
| 闭包嵌套深度 | 2 层 | 提取内层闭包为独立方法（见 coding-style.md Closure Simplicity） |
| 链式调用段数（`.map` `.filter` 等） | 3 段 | 拆成多行局部变量，每步命名 |

### 嵌套深度示例

```swift
// CORRECT — guard early return 消除嵌套，主逻辑无嵌套
func processOrder(_ order: OrderModel?) {
    // order 为 nil 时无法处理，提前退出
    guard let order else { return }
    // 已取消的订单无需处理
    guard order.status != .cancelled else { return }
    // 金额为 0 的订单跳过支付流程
    guard order.amount > 0 else { return }

    submitOrder(order)
}

// WRONG — 3 层嵌套，阅读时需要记住多层上下文
func processOrder(_ order: OrderModel?) {
    if let order {
        if order.status != .cancelled {
            if order.amount > 0 {
                submitOrder(order)
            }
        }
    }
}
```

### 链式调用示例

```swift
// CORRECT — 超过 3 段时拆成命名步骤，每步意图清晰
let activeItems = items.filter { $0.isActive }
let names = activeItems.map { $0.displayName }
let result = names.sorted()

// WRONG — 链式超过 3 段，阅读需要从右到左反向推导
let result = items.filter { $0.isActive }.map { $0.displayName }.sorted().prefix(10).map { $0.uppercased() }
```

## Implementation Choices — 实现选择

### 标准库 / 直白写法优先

能用 `for-in` 完成的遍历，**禁止**改用超过 3 段的函数式链式组合；能用普通属性完成的状态管理，**禁止**引入 Combine / `@Observable`。

```swift
// CORRECT — for-in 直白，意图一目了然
var selectedItems: [ItemModel] = []
for item in items where item.isSelected {
    selectedItems.append(item)
}

// WRONG — 简单过滤用 Combine pipeline，引入不必要的响应式依赖
let selectedItems = items.publisher
    .filter { $0.isSelected }
    .collect()
```

### 命名优于注释

好的命名能表达意图时，**禁止**用晦涩命名 + 注释的方式替代。变量名应直接说明其业务含义。

```swift
// CORRECT — 命名即文档
let isUserLoggedIn = checkLoginState()
let hasEditPermission = checkEditPermission()
if isUserLoggedIn && hasEditPermission {
    showEditButton()
}

// WRONG — flag 命名无意义，注释是命名失败的补救
let flag1 = checkLoginState() // 是否登录
let flag2 = checkEditPermission() // 是否有编辑权限
if flag1 && flag2 {
    showEditButton()
}
```

### 禁止为单调用点抽 helper

私有方法必须有 ≥ 2 个调用点，或逻辑复杂度足以独立（> 10 行 / 圈复杂度 > 3）。否则直接内联。

```swift
// CORRECT — 逻辑简单且只用一次，直接内联
func updateUI() {
    // 未登录时隐藏用户信息区域，避免展示空白占位
    userInfoView.isHidden = !isLoggedIn
    loginButton.isHidden = isLoggedIn
}

// WRONG — 2 行逻辑抽成只被调用一次的私有方法，增加跳转成本
func updateUI() {
    updateLoginState()
}

private func updateLoginState() {
    userInfoView.isHidden = !isLoggedIn
    loginButton.isHidden = isLoggedIn
}
```

## Logic Comments — 函数内逻辑注释规范

> 本节约束函数**内部**的 `//` 逻辑注释。类、属性、公共方法的 `///` doc comment 规范见 [coding-style.md](./coding-style.md#comments)。

### 规则（全部为 MUST）

- **`if` / `guard` 条件判断**：必须注释"判断边界 + 为什么这么判断"，不能只写条件本身
- **提前 `return` / `guard ... else { return }`**：必须注释"为什么提前 return"，说明跳过后续逻辑的业务原因
- **循环 `break` / `continue`**：必须注释"边界条件 + 为什么在此退出/跳过"
- **`switch` / 多分支 `if-else`**：每个 `case` 必须注释业务含义，不能只写技术条件

### Good 模板

```swift
func handleSeatUpdate(_ seatModel: SeatModel, at index: Int) {
    // 服务端偶发不下发 uid 字段，此时无法定位麦位，直接跳过
    guard !seatModel.uid.isEmpty else { return }

    // index 越界说明服务端数据与本地麦位数不一致，防止数组越界 crash
    guard index < seatViews.count else { return }

    let seatView = seatViews[index]
    let oldSeatView = uidToSeatViewMap[seatModel.uid]

    // 同一用户切换麦位时，先停旧麦位的视频流，再启新麦位
    // 不先停会导致两路视频同时渲染，出现画面撕裂
    if let oldSeatView, oldSeatView !== seatView {
        stopPlaying(at: oldSeatView)
    }

    for (_, view) in uidToSeatViewMap {
        // 跳过与当前更新无关的麦位，避免不必要的 UI 刷新
        guard view === seatView else { continue }
        // 找到目标麦位后无需继续遍历
        break
    }

    // 根据麦位状态决定渲染方式
    switch seatModel.status {
    case .empty:
        // 空麦位：显示占位图，停止视频渲染
        seatView.showEmptyState()
    case .muted:
        // 静音麦位：显示用户头像，停止视频但保留音频连接
        seatView.showMutedState(user: seatModel)
    case .active:
        // 活跃麦位：启动视频渲染
        seatView.showActiveState(user: seatModel)
        startPlaying(at: seatView, uid: seatModel.uid)
    }
}
```

### Bad 模板（同一逻辑，注释缺失）

```swift
// WRONG — 条件判断无说明，读者无法理解边界和原因
func handleSeatUpdate(_ seatModel: SeatModel, at index: Int) {
    guard !seatModel.uid.isEmpty else { return }
    guard index < seatViews.count else { return }

    let seatView = seatViews[index]
    let oldSeatView = uidToSeatViewMap[seatModel.uid]

    if let oldSeatView, oldSeatView !== seatView {
        stopPlaying(at: oldSeatView)
    }

    for (_, view) in uidToSeatViewMap {
        guard view === seatView else { continue }
        break
    }

    switch seatModel.status {
    case .empty:
        seatView.showEmptyState()
    case .muted:
        seatView.showMutedState(user: seatModel)
    case .active:
        seatView.showActiveState(user: seatModel)
        startPlaying(at: seatView, uid: seatModel.uid)
    }
}
```
