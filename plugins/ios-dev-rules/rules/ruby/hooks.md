---
paths:
  - "**/Gemfile"
  - "**/Podfile"
  - "**/Fastfile"
  - "**/*.rb"
  - "**/*.podspec"
  - "**/*.gemspec"
  - "**/Appfile"
  - "**/Matchfile"
---
# Ruby (iOS Tooling) Hooks

> This file extends [common/hooks.md](../common/hooks.md) with Ruby (iOS tooling) specific content.

## PostToolUse Hooks

Configure in `~/.claude/settings.json`:

- **RuboCop**: Auto-check `.rb`, `.podspec`, `Fastfile`, `Gemfile`, `Podfile` after edit
- **pod lib lint**: Validate podspec after `.podspec` changes

```jsonc
// Example hook config
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "bundle exec rubocop --autocorrect-all $FILE",
        "filePattern": "\\.(rb|podspec|gemspec)$|Fastfile|Podfile|Gemfile"
      },
      {
        "matcher": "Edit|Write",
        "command": "bundle exec pod lib lint --quick $FILE",
        "filePattern": "\\.podspec$"
      }
    ]
  }
}
```

## Warning

Flag `puts` / `p` debug statements in Fastlane actions — use `UI.message`, `UI.success`, `UI.error` instead.
