# ios-blocked-words-hook

iOS 禁止关键词 PostToolUse Hook — 当 Claude Code 通过 Edit/Write 修改 iOS 源码文件后，自动触发关键词检查。

## 功能

- **自动触发**：Edit 或 Write iOS 源码文件（`.h`/`.m`/`.mm`/`.swift`/`.c`/`.cpp`）后自动运行检查
- **非阻塞**：不会阻止 Edit/Write 操作，仅在发现违规时注入警告到 Claude 上下文
- **禁止提交**：检测到禁止关键词后提示禁止 git commit，直到问题修复
- **智能过滤**：非 iOS 文件自动跳过，零干扰

## 前置依赖

需要先安装 [ios-blocked-words-check](../ios-blocked-words-check/) skill（提供检查脚本）。

```bash
# 通过仓库安装脚本
./install.sh ios-blocked-words-check
```

## 安装

### 自动安装（推荐）

```bash
./install.sh ios-blocked-words-hook
```

安装脚本会自动将 hook 配置合并到 `~/.claude/settings.json`。

### 手动安装

将 `hooks/settings-snippet.json` 中的配置手动合并到 `~/.claude/settings.json` 的 `hooks.PostToolUse` 数组中：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // .tool_response.filePath // empty' | { read -r f; case \"$f\" in *.h|*.m|*.mm|*.swift|*.c|*.cpp) result=$(python3 \"$HOME/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py\" \"$f\" 2>&1); rc=$?; if [ $rc -ne 0 ]; then echo \"{\\\"hookSpecificOutput\\\":{\\\"hookEventName\\\":\\\"PostToolUse\\\",\\\"additionalContext\\\":\\\"iOS 禁止关键词检查失败，禁止 git commit。违规详情：\\n$result\\\"}}\"; fi ;; esac; }",
            "timeout": 30,
            "statusMessage": "iOS 禁止关键词检查中..."
          }
        ]
      }
    ]
  }
}
```

## 工作流程

```
Edit/Write iOS 文件
    ↓
PostToolUse Hook 触发
    ↓
判断文件扩展名是否为 iOS 源码
    ↓ 是                    ↓ 否
运行 check_blocked_words.py  静默跳过
    ↓
    ├─ 通过 → 无输出
    └─ 违规 → 注入警告到 Claude 上下文
              → 禁止 git commit
```

## Hook 配置说明

| 字段 | 值 | 说明 |
|------|-----|------|
| `matcher` | `Edit\|Write` | 匹配 Edit 和 Write 工具 |
| `type` | `command` | Shell 命令类型 hook |
| `timeout` | `30` | 30 秒超时 |
| `statusMessage` | `iOS 禁止关键词检查中...` | spinner 显示文本 |
