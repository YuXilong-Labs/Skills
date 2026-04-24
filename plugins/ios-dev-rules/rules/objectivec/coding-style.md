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
- Constants: `k` prefix + PascalCase (e.g. `kMaxRetryCount`)
- Enums: `NS_ENUM` / `NS_OPTIONS` with prefix (e.g. `XXUserStateActive`)

## Property Modifier Order

Always: `nonatomic`, memory, nullability, readwrite/readonly:

```objc
@property (nonatomic, strong, nullable) UIView *containerView;
@property (nonatomic, copy, nonnull) NSString *title;
@property (nonatomic, assign, readonly) BOOL isLoading;
```

## File Structure Template

```objc
// .h
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XXMyViewController : UIViewController
@property (nonatomic, copy) NSString *titleText;
- (void)reloadData;
@end

NS_ASSUME_NONNULL_END
```

## Pragma Mark Sections

Organize `.m` files in this order:

```objc
#pragma mark - Life Cycle
#pragma mark - Initialize
#pragma mark - Public
#pragma mark - Private
#pragma mark - Delegate (XXSomeDelegate)
#pragma mark - Getter & Setter
```

## NS_ENUM / NS_OPTIONS

Never use raw C enums. Always use typed macros:

```objc
typedef NS_ENUM(NSInteger, XXLoadState) {
    XXLoadStateIdle,
    XXLoadStateLoading,
    XXLoadStateDone,
    XXLoadStateFailed,
};
```

## Lightweight Generics

Use generics for collections:

```objc
@property (nonatomic, strong) NSArray<NSString *> *tags;
@property (nonatomic, strong) NSDictionary<NSString *, id<XXModel>> *modelMap;
```

## Block Retain Cycle Prevention

Always capture `weakSelf` before block, `strongSelf` inside:

```objc
__weak typeof(self) weakSelf = self;
[self fetchDataWithCompletion:^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf updateUI];
}];
```

## Nullability

Wrap all public headers with `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`. Mark nullable parameters explicitly.
