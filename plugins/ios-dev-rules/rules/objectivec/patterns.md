---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Patterns

> This file extends [common/patterns.md](../common/patterns.md) with Objective-C specific content.

## Delegate + Protocol

Define delegate protocol in the same header. Use `weak` for delegate property:

```objc
@protocol XXDataSourceDelegate <NSObject>
@optional
- (void)dataSource:(XXDataSource *)ds didUpdateItems:(NSArray<XXItem *> *)items;
@required
- (void)dataSourceDidFail:(XXDataSource *)ds withError:(NSError *)error;
@end

@interface XXDataSource : NSObject
@property (nonatomic, weak, nullable) id<XXDataSourceDelegate> delegate;
@end
```

## Category Organization

- File naming: `ClassName+Purpose.h/m`
- Prefix category methods to avoid collision with Apple or other libraries:

```objc
// UIColor+XXTheme.h
@interface UIColor (XXTheme)
+ (UIColor *)xx_primaryColor;
+ (UIColor *)xx_secondaryColor;
@end
```

## Singleton

Use `dispatch_once` + `allocWithZone:` guard:

```objc
+ (instancetype)sharedInstance {
    static XXManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}
```

## View Init Three-Phase Pattern

Separate view setup into three methods for clarity:

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    [self initializeViews];
    [self initializeViewLayout];
    [self initializeViewsAction];
}

- (void)initializeViews { /* create & addSubview */ }
- (void)initializeViewLayout { /* AutoLayout / frame */ }
- (void)initializeViewsAction { /* targets, gestures, delegates */ }
```

## Model Layer

- Implement `NSCopying` for model objects used as dictionary keys or passed across boundaries
- Use a consistent JSON mapping pattern (manual or library like YYModel/Mantle):

```objc
+ (NSDictionary *)modelCustomPropertyMapper {
    return @{
        @"userId"   : @"user_id",
        @"userName" : @"user_name",
    };
}
```

## Dealloc

Include debug logging in `dealloc` during development to catch retain cycles:

```objc
- (void)dealloc {
#ifdef DEBUG
    NSLog(@"[dealloc] %@", NSStringFromClass([self class]));
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```
