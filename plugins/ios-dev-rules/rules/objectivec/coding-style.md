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

Control statements (`if`/`else`/`for`/`while`/`switch`): opening brace on **same line** (K&R style):

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
