---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Hooks

> This file extends [common/hooks.md](../common/hooks.md) with Objective-C specific content.

## PostToolUse Hooks

Configure in `~/.claude/settings.json`:

- **clang-format**: Auto-format `.h`, `.m`, `.mm` files after edit

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "clang-format -i \"$TOOL_ARG_file_path\"",
        "filePattern": "\\.(h|m|mm)$"
      }
    ]
  }
}
```

## Warning

Flag `NSLog()` statements — use structured logging (e.g. `os_log`, `CocoaLumberjack`, or project-specific logger) instead for production code.

```objc
// Avoid in production
NSLog(@"user loaded: %@", user);

// Prefer
os_log_info(OS_LOG_DEFAULT, "user loaded: %{public}@", user.userId);
```
