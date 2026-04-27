---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Hooks

> This file extends [common/hooks.md](../common/hooks.md) with Objective-C specific content.

## PostToolUse Hooks

安装 `ios-dev-rules` 时会自动合并到 `~/.claude/settings.json`（需要 jq）。

- **clang-format**: Edit/Write `.h`, `.m`, `.mm` 文件后自动格式化
- 配置文件路径：`~/.claude/rules/objectivec/.clang-format`
- 使用 `-style=file:<path>` 显式指定，无需项目目录下存在 `.clang-format`

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "command",
      "command": "jq -r '.tool_input.file_path // .tool_response.filePath // empty' | { read -r f; case \"$f\" in *.h|*.m|*.mm) clang-format -style=\"file:$HOME/.claude/rules/objectivec/.clang-format\" -i \"$f\" 2>/dev/null ;; esac; }",
      "timeout": 15,
      "statusMessage": "ObjC clang-format 格式化中..."
    }
  ]
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
