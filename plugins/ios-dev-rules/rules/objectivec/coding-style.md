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

## Naming

- Class prefix: follow project conventions — detect from existing code, CLAUDE.md, or `.clang-format`. Do NOT invent a prefix
- Classes/Protocols: `PrefixPascalCase` (e.g. `XXUserManager`)
- Methods/Properties: `camelCase`
- Static constants: `k` prefix + PascalCase (e.g. `kModuleName`, `kDealloc`)
- Log module names: `static LoggerModuleName kModuleName = "ModuleName";`
- Enums: `NS_ENUM` / `NS_OPTIONS`, values prefixed with type name (e.g. `XXUserState_Active`)

## Property Declaration

No space between `@property` and `(`. Modifier order: `nonatomic`, memory, nullability, readwrite/readonly:

```objc
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign, readonly) BOOL isEnabled;
@property(nonatomic, weak) id<XXContainerViewDelegate> delegate;
@property(nonatomic, copy) void (^completionBlock)(void);
@property(nonatomic, strong, nullable) XXOverlayTipsView *tipsView;
```

Memory management rules:
- `strong` — general objects
- `copy` — NSString, NSArray, NSDictionary, Block
- `weak` — delegates, parent references
- `assign` — primitives (int, float, BOOL, NSUInteger, CGFloat)

## Brace Style

Method definitions: opening brace on **next line**. Control statements: opening brace on **same line**:

```objc
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

## Comments

- `///` for doc comments on classes, properties, public methods
- `///<` for inline enum value comments
- `//` for implementation notes
- `// MARK:` or `#pragma mark` for section dividers (prefer `#pragma mark`)

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
