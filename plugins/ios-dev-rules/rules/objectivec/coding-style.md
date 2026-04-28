---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Objective-C specific content.

## Formatting

- **clang-format** for auto-formatting — commit `.clang-format` to repo root
- Run `clang-format -i <file>` on save or via PostToolUse hook
- Indent width: **4 spaces** (not 2). Configure in `.clang-format`: `IndentWidth: 4`
- Column limit: **120** characters. Configure in `.clang-format`: `ColumnLimit: 120`

## Naming

- Class prefix: follow project conventions — detect from existing code, CLAUDE.md, or `.clang-format`. Do NOT invent a prefix
- Classes/Protocols: `PrefixPascalCase` (e.g. `XXUserManager`)
- Methods/Properties: `camelCase`
- 函数/方法名禁止以 `bt_` 开头 — 不使用任何自定义前缀修饰方法名
- Static constants: `k` prefix + PascalCase (e.g. `kModuleName`, `kDealloc`)
- Log module names: `static LoggerModuleName kModuleName = "ModuleName";`
- Enums: `NS_ENUM` / `NS_OPTIONS`, values prefixed with type name (e.g. `XXUserState_Active`)

## Property Declaration

No space between `@property` and `(`. Modifier order: `nonatomic`, memory, nullability, readwrite/readonly.

每个属性与其 `///` 注释之间空一行，提升可读性：

```objc
/// 内容容器
@property(nonatomic, strong) UIView *contentView;

/// 标题
@property(nonatomic, copy) NSString *title;

/// 是否可用
@property(nonatomic, assign, readonly) BOOL isEnabled;

/// 代理
@property(nonatomic, weak) id<XXContainerViewDelegate> delegate;

/// 完成回调
@property(nonatomic, copy) void (^completionBlock)(void);

/// 提示浮层
@property(nonatomic, strong, nullable) XXOverlayTipsView *tipsView;
```

Memory management rules:
- `strong` — general objects
- `copy` — NSString, NSArray, NSDictionary, Block
- `weak` — delegates, parent references
- `assign` — primitives (int, float, BOOL, NSUInteger, CGFloat)

## Brace Style

Method/function definitions: opening brace **must** be on the **next line** (Allman style). This is mandatory — never place the opening brace on the same line as the method signature:

Control statements (`if`/`else`/`for`/`while`/`switch`): opening brace on **same line** (K&R style). `} else {` 和 `} catch {` 保持同一行，不换行：

```objc
// CORRECT — method brace on next line
- (instancetype)initWithFrame:(CGRect)frame mode:(XXLayoutMode)mode
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeViews];
        [self initializeViewLayout];
        [self initializeViewsAction];
    }
    return self;
}

// CORRECT — getter brace on next line
- (NSUInteger)itemCount
{
    return _items.count;
}

// CORRECT — control statement brace on same line
if (condition) {
    // ...
} else {
    // ...
}

// WRONG — method brace on same line
- (void)updateUI {
    // ...
}
```

## Header File (.h) Structure

```objc
//
//  XXContainerView.h
//  XXModule
//
//  Created by author on 2024/01/01.
//

#import <UIKit/UIKit.h>
#import "XXModuleDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class XXItemModel;
@class XXNetworkError;

@protocol XXContainerViewDelegate;
@protocol XXContainerViewDataSource;

/// 容器视图
@interface XXContainerView : UIView

@property(nonatomic, assign, readonly) XXLayoutMode mode;
@property(nonatomic, weak) id<XXContainerViewDelegate> delegate;

- (instancetype)initWithFrame:(CGRect)frame mode:(XXLayoutMode)mode itemModel:(XXItemModel *)itemModel;

#pragma mark - 更新背景

/// 更新背景图片
- (void)updateBackgroundImageURL:(NSString *)imageURL;

@end

@protocol XXContainerViewDelegate <NSObject>
/// delegate methods...
@end

NS_ASSUME_NONNULL_END
```

Key points:
- `@class` forward declarations for all referenced types
- `@protocol` forward declarations before `@interface`
- `#pragma mark` sections in `.h` to group public API
- Protocol definitions at bottom of `.h`, after `@end`
- `///` doc comments for classes, properties, and public methods

## Implementation File (.m) Structure

Import order: self header → system/third-party frameworks → project headers:

```objc
#import "XXContainerView.h"
#import <XXFoundation/XXFoundation-Swift.h>
#import <XXUIKit/XXUIKit.h>

#import "XXItemView.h"
#import "XXItemModel.h"
```

## Pragma Mark Sections

Organize `.m` in this order. Use Chinese descriptions for business-specific sections:

```objc
#pragma mark - Life Cycle
#pragma mark - Initialize
#pragma mark - Public Methods
#pragma mark - Private Methods
#pragma mark - 初始化子视图列表
#pragma mark - 获取当前数据列表
#pragma mark - 更新子视图状态
#pragma mark - XXContainerViewDelegate
#pragma mark - Getter / Setter
```

## View Initialization Pattern

Three-phase init: create subviews → layout constraints → bind actions:

```objc
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

- (void)initializeViews
{
    _contentView = [[UIView alloc] init];
    [self addSubview:_contentView];
}

- (void)initializeViewLayout
{
    [_contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsZero);
    }];
}
```

## Auto Layout Constraints

Use **Masonry** for constraint setup. Always use `leading`/`trailing` for horizontal constraints — never `left`/`right` (RTL language support):

```objc
// CORRECT
make.leading.mas_equalTo(16.0);
make.trailing.mas_equalTo(-16.0);
make.leading.and.trailing.mas_equalTo(0.0);

// WRONG — breaks RTL layout
make.left.mas_equalTo(16.0);
make.right.mas_equalTo(-16.0);
```

- (void)initializeViewsAction
{
    // gestures, button targets, notifications
}
```

## Block Retain Cycle Prevention

Use `__weak __typeof(self)weakSelf = self;` — no space before variable name:

```objc
__weak __typeof(self)weakSelf = self;
[self fetchDataWithCompletion:^{
    [weakSelf updateUI];
}];
```

For blocks that need guaranteed self lifetime, add strongSelf:

```objc
__weak __typeof(self)weakSelf = self;
[self fetchDataWithCompletion:^{
    __strong __typeof(weakSelf)strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf.delegate containerView:strongSelf didFinishLoading:YES];
}];
```

## Property Access Style

Prefer ivar (`_propertyName`) over `self.propertyName` in implementation files. Use `self.` only when necessary:

```objc
// CORRECT — direct ivar access in normal code
_contentView = [[UIView alloc] init];
_contentView.hidden = YES;
[self addSubview:_contentView];

// CORRECT — self. required inside blocks (weakSelf/strongSelf pattern)
__weak __typeof(self)weakSelf = self;
[self fetchDataWithCompletion:^{
    weakSelf.contentView.hidden = NO;
}];

// CORRECT — self. in KVO-observed or custom setter/getter scenarios
self.mode = XXLayoutMode_Grid;  // triggers custom setter

// WRONG — unnecessary self. in normal implementation code
self.contentView = [[UIView alloc] init];
self.contentView.hidden = YES;
```

## Comments

Every class, property, public method, and non-trivial logic block must have a comment. Use `///` for doc comments, `///<` for inline enum values, `//` for logic notes:

```objc
/// 红包弹窗视图
@interface XXRedPacketView : UIView

/// 红包icon
@property(nonatomic, strong) UIImageView *iconView;

/// 金额标签
@property(nonatomic, strong) UILabel *amountLabel;

/// 显示红包弹窗
/// - Parameters:
///   - amount: 红包金额（单位：分）
///   - animated: 是否带动画
- (void)showWithAmount:(NSInteger)amount animated:(BOOL)animated;

@end
```

Logic comments for non-obvious code paths:

```objc
- (void)updateSeatModel:(XXSeatModel *)seatModel
{
    // 服务端偶发没有uid字段，需要防护
    if (!NSStringIsVaild(seatModel.uid)) return;

    // 同一用户切换麦位时，先停旧麦位的视频再启新麦位
    if (oldSeatView && oldSeatView != seatView) {
        [self stopPlayingAtSeatView:oldSeatView];
    }
}
```

Enum inline comments:

```objc
/// 布局模式
typedef NS_ENUM(NSUInteger, XXLayoutMode) {
    XXLayoutMode_None = 0,    ///< 不支持
    XXLayoutMode_Grid = 1,    ///< 网格布局
    XXLayoutMode_List = 2,    ///< 列表布局
};
```

## NS_ENUM / NS_OPTIONS

Never use raw C enums. Use `NS_ENUM` with explicit values when meaningful:

```objc
typedef NS_ENUM(NSUInteger, XXLayoutMode) {
    XXLayoutMode_None = 0,
    XXLayoutMode_Grid = 1,
    XXLayoutMode_List = 2,
    XXLayoutMode_Flow = 3,
};
```

## Lightweight Generics

Use generics for all collection properties:

```objc
@property(nonatomic, strong) NSMutableDictionary<NSString *, XXItemView *> *itemViewMap;
@property(nonatomic, strong) NSMutableSet<NSString *> *activeUserIds;
@property(nonatomic, strong) NSArray<XXItemModel *> *items;
```

## Collection Initialization

非静态数据禁止使用字面量 `@[]` / `@{}` 初始化集合。字面量仅用于编译期已知的静态常量。动态数据必须使用 `NSMutableArray` / `NSMutableDictionary` 逐个添加：

```objc
// CORRECT — 静态常量可以用字面量
static NSArray *const kSupportedTypes = @[@"type1", @"type2", @"type3"];

// CORRECT — 动态数据用 mutable + addObject
NSMutableArray *items = [NSMutableArray array];
for (XXModel *model in dataList) {
    if (model.isValid) {
        [items addObject:model];
    }
}

NSMutableDictionary *params = [NSMutableDictionary dictionary];
params[@"uid"] = uid;
params[@"ts"] = @(timestamp);

// WRONG — 动态数据用字面量，元素可能为 nil 导致 crash
NSArray *items = @[model1, model2, model3];
NSDictionary *params = @{@"uid": uid, @"ts": @(timestamp)};
```

## Dealloc

Every class should implement `dealloc` with debug logging and cleanup:

```objc
- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    XX_LOG_DEBUG(kDealloc, @"%s", __PRETTY_FUNCTION__);
}
```

## Nullability

Wrap all public headers with `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`. Mark nullable parameters and return values explicitly:

```objc
- (UIView * _Nullable)renderViewForUid:(NSString *)uid;
@property(nonatomic, strong, nullable) XXThemeModel *themeModel;
```

## Static Inline Functions

Use for simple utility conversions in header files:

```objc
static inline XXLayoutMode XXLayoutModeFromCount(NSInteger count) {
    XXLayoutMode mode = XXLayoutMode_None;
    switch (count) {
        case 4: mode = XXLayoutMode_Grid; break;
        case 6: mode = XXLayoutMode_List; break;
        default: break;
    }
    return mode;
}
```

## Enumeration Safety

遍历可变数组时必须先 copy 再遍历，防止遍历过程中原数组被修改导致 crash：

```objc
// CORRECT — copy 后遍历
NSArray *snapshot = [_mutableItems copy];
for (XXItemModel *item in snapshot) {
    [self processItem:item];
}

// WRONG — 直接遍历可变数组，遍历中若有增删会 crash
for (XXItemModel *item in _mutableItems) {
    [self processItem:item];
}
```

其他遍历规则：
- 不要修改循环变量，防止循环失控
- 避免在循环中重复调用高开销方法（内存分配、网络请求、文件 I/O）
- 优先使用 NSDictionary key-value 查找替代数组线性遍历

## Collection Safety

数组操作必须做防护，避免 nil 插入和越界 crash：

```objc
// addObject 前判空
if (model) {
    [_items addObject:model];
}

// 下标访问前检查越界
if (index < _items.count) {
    XXItemModel *item = _items[index];
}

// 取首尾元素用 firstObject / lastObject（空数组返回 nil，不会 crash）
XXItemModel *first = _items.firstObject;
XXItemModel *last = _items.lastObject;
```

## Server Data Validation

服务端返回的数据使用前必须校验格式，避免因数据异常导致 crash：

```objc
if (NSStringIsValid(model.uid)) {
    // 安全使用 uid
}

if (NSDictionaryIsValid(responseDict)) {
    // 安全解析字典
}
```

## NSNotification

- 通知名称必须定义为 `static NSString *const` 常量
- 在 `dealloc` 中移除通知监听

```objc
// 常量定义
static NSString *const kUserDidLoginNotification = @"UserDidLoginNotification";

// 注册
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLogin:) name:kUserDidLoginNotification object:nil];

// dealloc 中移除
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

## NSTimer Weak Proxy

NSTimer 会强持有 target，必须使用 WeakProxy 打破强引用，避免内存泄漏：

```objc
// CORRECT
_timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                          target:[XXWeakProxy proxyWithTarget:self]
                                        selector:@selector(timerFired)
                                        userInfo:nil
                                         repeats:YES];

// WRONG — Timer 强持有 self，ViewController 无法释放
_timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                          target:self
                                        selector:@selector(timerFired)
                                        userInfo:nil
                                         repeats:YES];
```

## Category Method Prefix

分类中的方法必须添加模块前缀 + 下划线，避免与系统方法或其他分类命名冲突：

```objc
@interface NSDate (XXTimeExtensions)

/// 返回简短的时间描述
- (NSString *)xx_timeAgoShort;

@end
```

## Variable Declaration

局部变量应尽量接近其使用位置，避免在方法开头集中定义：

```objc
// CORRECT — 就近定义
- (void)processData
{
    NSInteger index = [self findTargetIndex];
    [self handleAtIndex:index];

    NSString *name = [self fetchName];
    [self displayName:name];
}

// WRONG — 集中定义，阅读时需要上下跳转
- (void)processData
{
    NSInteger index = [self findTargetIndex];
    NSString *name = [self fetchName];

    [self handleAtIndex:index];
    [self displayName:name];
}
```

## Early Return

避免多重嵌套分支，使用提前返回简化代码。复杂条件提取为具名 BOOL 变量提升可读性：

```objc
// CORRECT — 提前返回
- (void)processData:(NSData *)data
{
    if (!data) return;
    if (data.length == 0) return;

    // 正常处理逻辑
}

// CORRECT — 复杂条件提取为具名变量
BOOL isUserLoggedIn = [self isUserLoggedIn];
BOOL hasPermission = [self checkPermission];
if (isUserLoggedIn && hasPermission) {
    [self loadContent];
}
```

## Single Responsibility — Files & Models

- 不要在同一个 Model 文件里创建 SubModel，应分开独立文件
- 不要在一个类文件内创建子类实现
- 每个 `.h` / `.m` 文件只包含一个主类定义

## Core Foundation Resource Management

Core Foundation 对象必须手动管理生命周期，使用完毕后及时 CFRelease：

```objc
CFStringRef cfStr = CFStringCreateWithCString(NULL, "Hello", kCFStringEncodingUTF8);
// 使用 cfStr
CFRelease(cfStr);
```
