---
name: wk-sync-pb
description: >
  同步上游 proto submodule 并重新生成 ObjC Protobuf 代码的完整自动化工作流。
  TRIGGER: 用户执行 /wk-sync-pb 命令时触发。
  流程：拉取上游 proto → 生成 ObjC 代码 → 敏感词检查 → 用户确认 → 提交推送。
---

# 同步上游 Proto 并重新生成 PB 代码

## 完整工作流

严格按以下步骤顺序执行，每步完成后输出简要状态。

### 步骤 1：前置检查

确认当前工作目录包含以下文件/目录，任一缺失则终止并提示用户：

- `proto/mqtt-idl/` — proto submodule 目录
- `scripts/generate_protobuf.sh` — 代码生成脚本

检查命令：

```bash
[ -d "proto/mqtt-idl" ] && echo "✅ submodule 目录存在" || echo "❌ 缺少 proto/mqtt-idl 目录"
[ -f "scripts/generate_protobuf.sh" ] && echo "✅ 生成脚本存在" || echo "❌ 缺少 scripts/generate_protobuf.sh"
```

如果检查失败，输出提示并**终止流程**。

### 步骤 2：拉取上游 proto

执行 submodule 更新，拉取上游最新 proto 定义：

```bash
git submodule update --remote proto/mqtt-idl
```

拉取完成后，输出 submodule 的 diff 摘要：

```bash
cd proto/mqtt-idl && git log --oneline -10 && cd ../..
```

### 步骤 3：生成 ObjC 代码

执行生成脚本，**将输出重定向到临时文件**，仅展示尾部 50 行：

```bash
TMPLOG=$(mktemp /tmp/pb_generate_XXXXXX.log)
bash scripts/generate_protobuf.sh > "$TMPLOG" 2>&1
echo "--- 生成日志尾部 ---"
tail -50 "$TMPLOG"
```

如果脚本退出码非 0，输出完整错误并**终止流程**。

### 步骤 4：敏感词检查

使用 ios-blocked-words-check skill 对生成目录执行批量检查：

```bash
python3 ~/.claude/skills/ios-blocked-words-check/scripts/check_blocked_words.py \
  --all BTProtobufMessages/Classes/PB \
  --skip-comments --summary \
  --trace-proto proto/mqtt-idl
```

将检查结果汇总后展示给用户。

### 步骤 5：用户确认

使用 **AskUserQuestion** 工具让用户选择下一步操作：

- **忽略敏感词并提交推送** — 上游 proto 生成的敏感词无法在本仓库修改，跳过并继续
- **仅提交不推送** — 提交到本地但不推送远端
- **停止** — 中断流程，不做任何 git 操作

### 步骤 6：提交推送

根据用户选择执行 git 操作：

```bash
# 添加所有变更
git add proto/mqtt-idl
git add BTProtobufMessages/Classes/

# 提交（使用 --no-verify 跳过 hook，因为上游 proto 生成的敏感词无法避免）
git commit --no-verify -m "feat: 同步上游 proto 并重新生成 ObjC 代码"

# 如用户选择推送
git push
```

提交完成后输出 `git log --oneline -3` 确认。

## 注意事项

- 本工作流仅适用于 BTProtobufMessages 项目
- `--no-verify` 仅用于跳过敏感词 pre-commit hook，因为上游 proto 字段命名不可控
- 如果 submodule 没有变更（已是最新），流程会正常完成但 diff 为空
