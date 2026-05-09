---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Simplicity Rules

> 本文件与 [coding-style.md](./coding-style.md) 并列，专门约束实现复杂度与函数内逻辑注释规范。
> Early Return 格式规范见 [coding-style.md#early-return](./coding-style.md)。

## Core Principles

### Simplicity First — 优先最简实现

**实现前必须先想最简方案**，只有在最简方案确实无法满足需求时，才允许引入更复杂的结构。禁止为了"看起来更工程化"而增加不必要的层次。

```objc
// CORRECT — 直接 for-in 累加，意图清晰
NSInteger total = 0;
for (XXItemModel *item in items) {
    total += item.price;
}

// WRONG — 为简单求和提前抽 Strategy 协议 + 工厂，过度设计
id<XXAggregationStrategy> strategy = [XXAggregationStrategyFactory strategyForType:XXAggregationTypeSum];
NSInteger total = [strategy aggregateItems:items];
```

### YAGNI — 禁止过度抽象

禁止为"将来可能的扩展"提前引入协议、泛型、工厂、多态。当前只有一个实现时，**必须**直接写实现类，不得提前抽协议。

```objc
// CORRECT — 当前只有一种数据源，直接实现
@interface XXUserDataSource : NSObject
- (NSArray<XXUserModel *> *)fetchUsers;
@end

// WRONG — 只有一个实现却提前抽协议，增加无谓的间接层
@protocol XXDataSourceProtocol <NSObject>
- (NSArray *)fetchItems;
@end
@interface XXUserDataSource : NSObject <XXDataSourceProtocol>
@end
```

### 禁止过度封装

禁止为单一调用点抽取 helper 方法；禁止为简单类型包装 wrapper 类。封装必须有明确的复用价值（≥ 2 个调用点，或逻辑行数 > 10 行 / 圈复杂度 > 3）。

```objc
// CORRECT — 3 行逻辑直接写在调用处，无需封装
NSString *displayName = _user.nickname.length > 0 ? _user.nickname : _user.uid;
_label.text = displayName;
_label.hidden = displayName.length == 0;

// WRONG — 只被调用一次的私有 helper，增加跳转成本
- (void)_configureDisplayNameLabel
{
    NSString *displayName = _user.nickname.length > 0 ? _user.nickname : _user.uid;
    _label.text = displayName;
    _label.hidden = displayName.length == 0;
}
```

## Quantitative Constraints — 量化硬性阈值

| 维度 | 上限 | 超出后的处理方式 |
|------|------|-----------------|
| 条件/循环嵌套深度 | 3 层 | 用 early return 或提取方法消除嵌套 |
| 单函数/方法行数 | 40 行 | 拆分为多个职责单一的方法 |
| 单文件行数 | 400 行 | 拆分为多个文件，每文件一个主类 |
| 圈复杂度 | 10 | 提取方法或简化分支逻辑 |
| Block/闭包嵌套深度 | 2 层 | 提取内层 Block 为独立方法 |
| 链式方法调用段数 | 3 段 | 拆成多行局部变量，每步命名 |

### 嵌套深度示例

```objc
// CORRECT — early return 消除嵌套，主逻辑无嵌套
- (void)processOrder:(XXOrderModel *)order
{
    // 订单为空时无法处理，提前退出
    if (!order) return;
    // 订单已取消，无需处理
    if (order.status == XXOrderStatus_Cancelled) return;
    // 金额为 0 的订单跳过支付流程
    if (order.amount == 0) return;

    [self submitOrder:order];
}

// WRONG — 3 层嵌套，阅读时需要记住多层上下文
- (void)processOrder:(XXOrderModel *)order
{
    if (order) {
        if (order.status != XXOrderStatus_Cancelled) {
            if (order.amount > 0) {
                [self submitOrder:order];
            }
        }
    }
}
```

### 单函数行数示例

```objc
// CORRECT — 拆分为三阶段方法，每个方法职责单一（参见 coding-style.md View Init Three-Phase Pattern）
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeViews];
        [self initializeViewLayout];
        [self initializeViewsAction];
    }
    return self;
}

// WRONG — 一个 init 方法承担创建、布局、绑定三种职责，超过 40 行
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _titleLabel = [[UILabel alloc] init];
        // ... 20 行创建代码 ...
        [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) { /* ... */ }];
        // ... 20 行布局代码 ...
        [_button addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
        // ... 10 行绑定代码 ...
    }
    return self;
}
```

## Implementation Choices — 实现选择

### 标准库 / 直白写法优先

能用 `for-in` 完成的遍历，**禁止**改用 `enumerateObjectsUsingBlock:` 加多层 Block；能用普通属性完成的状态管理，**禁止**引入 KVO。

```objc
// CORRECT — for-in 直白，意图一目了然
for (XXItemModel *item in _items) {
    if (item.isSelected) {
        [selectedItems addObject:item];
    }
}

// WRONG — enumerateObjectsUsingBlock: 增加 Block 嵌套，无额外收益
[_items enumerateObjectsUsingBlock:^(XXItemModel *item, NSUInteger idx, BOOL *stop) {
    if (item.isSelected) {
        [selectedItems addObject:item];
    }
}];
```

### 命名优于注释

好的命名能表达意图时，**禁止**用晦涩命名 + 注释的方式替代。变量名应直接说明其业务含义。

```objc
// CORRECT — 命名即文档
BOOL isUserLoggedIn = [self isUserLoggedIn];
BOOL hasEditPermission = [self checkEditPermission];
if (isUserLoggedIn && hasEditPermission) {
    [self showEditButton];
}

// WRONG — flag 命名无意义，注释是命名失败的补救
BOOL flag1 = [self isUserLoggedIn]; // 是否登录
BOOL flag2 = [self checkEditPermission]; // 是否有编辑权限
if (flag1 && flag2) {
    [self showEditButton];
}
```

### 禁止为单调用点抽 helper

私有方法必须有 ≥ 2 个调用点，或逻辑复杂度足以独立（> 10 行 / 圈复杂度 > 3）。否则直接内联。

```objc
// CORRECT — 逻辑简单且只用一次，直接内联
- (void)updateUI
{
    // 未登录时隐藏用户信息区域，避免展示空白占位
    _userInfoView.hidden = !_isLoggedIn;
    _loginButton.hidden = _isLoggedIn;
}

// WRONG — 2 行逻辑抽成只被调用一次的私有方法，增加跳转成本
- (void)updateUI
{
    [self _updateLoginState];
}

- (void)_updateLoginState
{
    _userInfoView.hidden = !_isLoggedIn;
    _loginButton.hidden = _isLoggedIn;
}
```

## Logic Comments — 函数内逻辑注释规范

> 本节约束函数**内部**的 `//` 逻辑注释。类、属性、公共方法的 `///` doc comment 规范见 [coding-style.md](./coding-style.md#comments)。

### 规则（全部为 MUST）

- **`if` 条件判断**：必须注释"判断边界 + 为什么这么判断"，不能只写条件本身
- **提前 `return`**：必须注释"为什么提前 return"，说明跳过后续逻辑的业务原因
- **循环 `break` / `continue`**：必须注释"边界条件 + 为什么在此退出/跳过"
- **`switch` / 多分支 `if-else`**：每个分支必须注释业务含义，不能只写技术条件

### Good 模板

```objc
- (void)handleSeatUpdate:(XXSeatModel *)seatModel atIndex:(NSUInteger)index
{
    // 服务端偶发不下发 uid 字段，此时无法定位麦位，直接跳过
    if (!NSStringIsValid(seatModel.uid)) return;

    // index 越界说明服务端数据与本地麦位数不一致，防止数组越界 crash
    if (index >= _seatViews.count) return;

    XXSeatView *seatView = _seatViews[index];
    XXSeatView *oldSeatView = _uidToSeatViewMap[seatModel.uid];

    // 同一用户切换麦位时，先停旧麦位的视频流，再启新麦位
    // 不先停会导致两路视频同时渲染，出现画面撕裂
    if (oldSeatView && oldSeatView != seatView) {
        [self stopPlayingAtSeatView:oldSeatView];
    }

    for (NSString *uid in [_uidToSeatViewMap.allKeys copy]) {
        XXSeatView *view = _uidToSeatViewMap[uid];
        // 跳过与当前更新无关的麦位，避免不必要的 UI 刷新
        if (view != seatView) continue;
        // 找到目标麦位后无需继续遍历
        break;
    }

    // 根据麦位状态决定渲染方式
    switch (seatModel.status) {
        case XXSeatStatus_Empty:
            // 空麦位：显示占位图，停止视频渲染
            [seatView showEmptyState];
            break;
        case XXSeatStatus_Muted:
            // 静音麦位：显示用户头像，停止视频但保留音频连接
            [seatView showMutedStateWithUser:seatModel];
            break;
        case XXSeatStatus_Active:
            // 活跃麦位：启动视频渲染
            [seatView showActiveStateWithUser:seatModel];
            [self startPlayingAtSeatView:seatView uid:seatModel.uid];
            break;
        default:
            break;
    }
}
```

### Bad 模板（同一逻辑，注释缺失）

```objc
// WRONG — 条件判断无说明，读者无法理解边界和原因
- (void)handleSeatUpdate:(XXSeatModel *)seatModel atIndex:(NSUInteger)index
{
    if (!NSStringIsValid(seatModel.uid)) return;
    if (index >= _seatViews.count) return;

    XXSeatView *seatView = _seatViews[index];
    XXSeatView *oldSeatView = _uidToSeatViewMap[seatModel.uid];

    if (oldSeatView && oldSeatView != seatView) {
        [self stopPlayingAtSeatView:oldSeatView];
    }

    for (NSString *uid in [_uidToSeatViewMap.allKeys copy]) {
        XXSeatView *view = _uidToSeatViewMap[uid];
        if (view != seatView) continue;
        break;
    }

    switch (seatModel.status) {
        case XXSeatStatus_Empty:
            [seatView showEmptyState];
            break;
        case XXSeatStatus_Muted:
            [seatView showMutedStateWithUser:seatModel];
            break;
        case XXSeatStatus_Active:
            [seatView showActiveStateWithUser:seatModel];
            [self startPlayingAtSeatView:seatView uid:seatModel.uid];
            break;
        default:
            break;
    }
}
```
