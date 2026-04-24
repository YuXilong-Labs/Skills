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
- Classes/Protocols: `PrefixPascalCase` (e.g. `BTRoomPartyView`)
- Methods/Properties: `camelCase`
- Static constants: `k` prefix + PascalCase (e.g. `kPartyRoom`, `kDealloc`)
- Log module names: `static LoggerModuleName kModuleName = "ModuleName";`
- Enums: `NS_ENUM` / `NS_OPTIONS`, values prefixed with type name (e.g. `LiveRoomPartyMode_Four`)

## Property Declaration

No space between `@property` and `(`. Modifier order: `nonatomic`, memory, nullability, readwrite/readonly:

```objc
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign, readonly) BOOL isMainHostMode;
@property(nonatomic, weak) id<BTRoomPartyViewDelegate> delegate;
@property(nonatomic, copy) void (^completionBlock)(void);
@property(nonatomic, strong, nullable) BTRoomScreenRecordingTipsView *tipsView;
```

Memory management rules:
- `strong` — general objects
- `copy` — NSString, NSArray, NSDictionary, Block
- `weak` — delegates, parent references
- `assign` — primitives (int, float, BOOL, NSUInteger, CGFloat)

## Brace Style

Method definitions: opening brace on **next line**. Control statements: opening brace on **same line**:

```objc
- (instancetype)initWithFrame:(CGRect)frame mode:(LiveRoomPartyMode)mode
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
//  BTRoomPartyView.h
//  BTLiveRoom
//
//  Created by yuxilong on 2024/01/01.
//

#import <UIKit/UIKit.h>
#import "BTLiveRoomPartyDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class BTRoomInfoModel;
@class BTNetworkError;

@protocol BTRoomPartyViewDelegate;
@protocol BTRoomPartyViewDataSource;

/// 直播间多人直播控件
@interface BTRoomPartyView : UIView

@property(nonatomic, assign, readonly) LiveRoomPartyMode mode;
@property(nonatomic, weak) id<BTRoomPartyViewDelegate> delegate;

- (instancetype)initWithFrame:(CGRect)frame mode:(LiveRoomPartyMode)mode liveUserModel:(BTRoomInfoModel *)liveUserModel;

#pragma mark - 更新背景图

/// 更新房间背景
- (void)updateBackgroundImageURL:(NSString *)imageURL;

@end

@protocol BTRoomPartyViewDelegate <NSObject>
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
#import "BTRoomPartyView.h"
#import <BTRtcEngine/BTRtcEngine-Swift.h>
#import <BTComponentsKit/BTComponentsKit.h>

#import "BTRoomPartySeatView.h"
#import "BTRoomInfoModel.h"
```

## Pragma Mark Sections

Organize `.m` in this order. Use Chinese descriptions for business-specific sections:

```objc
#pragma mark - Life Cycle
#pragma mark - Initialize
#pragma mark - Public Methods
#pragma mark - Private Methods
#pragma mark - 初始化麦位列表
#pragma mark - 获取当前房间的麦位列表
#pragma mark - 更新麦位信息
#pragma mark - BTRoomPartyViewDelegate
#pragma mark - Getter / Setter
```

## View Initialization Pattern

Three-phase init: create subviews → layout constraints → bindactions:

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
    [strongSelf.delegate partyView:strongSelf didFinishLoading:YES];
}];
```

## Comments

- `///` for doc comments on classes, properties, public methods
- `///<` for inline enum value comments
- `//` for implementation notes
- `// MARK:` or `#pragma mark` for section dividers (prefer `#pragma mark`)

```objc
/// 多人直播模式
typedef NS_ENUM(NSUInteger, LiveRoomPartyMode) {
    LiveRoomPartyMode_UnSupport = 0, ///< 不支持
    LiveRoomPartyMode_Four = 4,      ///< 四人房
    LiveRoomPartyMode_Six = 6,       ///< 六人房
};
```

## NS_ENUM / NS_OPTIONS

Never use raw C enums. Use `NS_ENUM` with explicit values when meaningful:

```objc
typedef NS_ENUM(NSUInteger, LiveRoomPartyMode) {
    LiveRoomPartyMode_UnSupport = 0,
    LiveRoomPartyMode_Four = 4,
    LiveRoomPartyMode_Six = 6,
    LiveRoomPartyMode_Nine = 9,
};
```

## Lightweight Generics

Use generics for all collection properties:

```objc
@property(nonatomic, strong) NSMutableDictionary<NSString *, BTRoomPartySeatView *> *seatViewDic;
@property(nonatomic, strong) NSMutableSet<NSString *> *playingRemoteUsers;
@property(nonatomic, strong) NSArray<BTRoomSeatModel *> *seats;
```

## Dealloc

Every class should implement `dealloc` with debug logging and cleanup:

```objc
- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    BT_LOG_DEBUG(kDealloc, @"%s", __PRETTY_FUNCTION__);
}
```

## Nullability

Wrap all public headers with `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`. Mark nullable parameters and return values explicitly:

```objc
- (UIView * _Nullable)videoRenderViewForUid:(NSString *)uid;
@property(nonatomic, strong, nullable) BTRoomSuperPartyThemeModel *superPartyThemeModel;
```

## Static Inline Functions

Use for simple utility conversions in header files:

```objc
static inline LiveRoomPartyMode LiveRoomPartyModeFrom(NSInteger seatCount, BOOL isMainGuestMode) {
    LiveRoomPartyMode mode = LiveRoomPartyMode_UnSupport;
    switch (seatCount) {
        case 4: mode = LiveRoomPartyMode_Four; break;
        case 6: mode = LiveRoomPartyMode_Six; break;
        default: break;
    }
    return mode;
}
```
