---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Hooks

> This file extends [common/hooks.md](../common/hooks.md) with Swift specific content.

## PostToolUse Hooks

Configure in `~/.claude/settings.json`:

- **SwiftFormat**: Auto-format `.swift` files after edit
- **SwiftLint**: Run lint checks after editing `.swift` files
- **swift build**: Type-check modified packages after edit

### swift-format (Xcode 16+ bundled)

Xcode 16+ ships `swift-format` at `/usr/bin/swift-format`. Use as a PostToolUse hook:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "swift-format format --in-place \"$FILEPATH\"",
        "filePattern": "*.swift"
      }
    ]
  }
}
```

- Prefer `swift-format` over third-party SwiftFormat when Xcode 16+ is available
- Configure via `.swift-format` JSON file at project root

## Warnings

Flag `print()` statements — use `os.Logger` or structured logging instead for production code.

### Force Unwraps

Flag all force unwraps (`!`) in production code:

- `as!` — use `as?` with guard/if-let instead
- `try!` — use `do/catch` or `try?` with fallback
- Optional `!` — use `guard let` or `if let`
- Exception: `IBOutlet`, test code, and truly invariant preconditions (document why)

### @MainActor Scope

Avoid `@MainActor` on large scopes unnecessarily:

```swift
// WRONG — entire class on main actor, blocks UI for non-UI work
@MainActor class DataProcessor { ... }

// RIGHT — isolate only UI-touching methods
class DataProcessor {
    @MainActor func updateUI(with result: Result) { ... }
    func process(_ data: Data) async -> Result { ... }
}
```

- Apply `@MainActor` to individual methods/properties that touch UI
- Never mark model/service layers as `@MainActor`
- Use `MainActor.run {}` for one-off main-thread hops
