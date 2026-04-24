---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Security

> This file extends [common/security.md](../common/security.md) with Objective-C specific content.

## Secret Management

- Use **Keychain Services** for tokens, passwords, keys — never `NSUserDefaults`
- Use `.xcconfig` files for build-time secrets, never hardcode in source
- Decompilation tools (`class-dump`, Hopper) extract string literals trivially

```objc
// WRONG
NSString *apiKey = @"sk-abc123";

// RIGHT — load from Keychain or environment
NSString *apiKey = [XXKeychainHelper valueForKey:@"api_key"];
NSAssert(apiKey.length > 0, @"API key not configured");
```

## Transport Security

- App Transport Security (ATS) is enforced by default — do not add `NSAllowsArbitraryLoads`
- Use certificate pinning for critical endpoints via `NSURLSessionDelegate`
- Validate server trust in `URLSession:didReceiveChallenge:completionHandler:`

## Input Validation

- Validate URL schemes and deep link parameters before routing:

```objc
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary *)options {
    if (![url.scheme isEqualToString:@"myapp"]) return NO;
    NSString *action = url.host;
    if (!action || action.length == 0) return NO;
    // validate action against allowlist
    return [self handleAction:action params:url.queryParameters];
}
```

- Sanitize pasteboard content before use — never trust `UIPasteboard.generalPasteboard`

## Format String Safety

Never pass user input as format string:

```objc
// WRONG — format string attack vector
NSLog(userInput);
[NSString stringWithFormat:userInput];

// RIGHT
NSLog(@"%@", userInput);
[NSString stringWithFormat:@"%@", userInput];
```

## Memory & Retain Cycles

- Always use `weakSelf` / `strongSelf` pattern in blocks that capture `self`
- Use `__weak` for delegate properties
- Audit `NSTimer`, `NSNotificationCenter`, `KVO` for missing invalidation / removal in `dealloc`
