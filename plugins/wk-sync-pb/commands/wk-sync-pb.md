---
description: 同步上游 proto submodule 并重新生成 ObjC Protobuf 代码（含敏感词检查与自动提交推送）
mode: skill
skill_file: skills/wk-sync-pb/SKILL.md
---

# /wk-sync-pb

一键同步上游 proto 并重新生成 Protobuf ObjC 代码。

## 用法

```
/wk-sync-pb
```

## 完整流程

1. 前置检查（submodule、生成脚本是否存在）
2. 拉取上游 proto 最新代码
3. 执行 `generate_protobuf.sh` 生成 ObjC 文件
4. 运行敏感词检查
5. 用户确认后提交并推送

## 使用示例

```
/wk-sync-pb
```

在 BTProtobufMessages 项目根目录下执行即可。

$ARGUMENTS
