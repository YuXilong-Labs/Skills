# wk-sync-pb

同步上游 proto submodule 并重新生成 Objective-C Protobuf 代码。

## 功能

一键完成以下流程：

1. **前置检查** — 确认 submodule 和生成脚本存在
2. **拉取上游** — `git submodule update --remote` 获取最新 proto
3. **生成代码** — 执行 `generate_protobuf.sh` 生成 ObjC 文件
4. **敏感词检查** — 自动扫描生成文件中的 App Store 审核禁止关键词
5. **用户确认** — 选择提交推送 / 仅提交 / 停止
6. **提交推送** — 自动 commit & push

## 安装

```bash
cd /path/to/Skills
bash install.sh wk-sync-pb
```

## 使用

在 BTProtobufMessages 项目目录下：

```
/wk-sync-pb
```

## 依赖

- `ios-blocked-words-check` skill（敏感词检查）
- `protoc` 编译器（生成脚本内置本地版本）

## 适用项目

BTProtobufMessages（BaiTuPods 组件库）
