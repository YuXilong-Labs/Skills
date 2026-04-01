# wk-lark-wiki

iOS 组件库 API 文档生成、AI 深度润色与飞书知识库上传一体化工作流。

## 功能

- **双上下文支持** — 在 `mcp-ios-components` 项目或任意 CocoaPods 组件目录（含 `.podspec`）下均可使用
- **增量文档生成** — 基于源码 hash 的差异检测，仅重新生成变更部分
- **文件目录架构图** — 每份文档自动包含模块目录结构（含注释）
- **源码验证润色** — AI 读取源码实现验证并修正 API 描述准确性
- **增量润色** — 基于文档内容 hash 的差异检测，仅润色变更章节
- **飞书 update-or-create** — 上传时先查已有文档更新，不存在再创建，避免重复
- **分支保护** — 文档生成仅允许在 main/master 分支执行
- **Git 追踪** — 生成的文档缓存在 `docs/api/` 并自动 stage 到 git
- **单组件支持** — 可指定单个组件或文件操作

## 前置条件

### 在 mcp-ios-components 项目中使用
- 已构建索引缓存（`.cache/index.json`）
- `tools/generate_api_docs.py` 可用

### 在 CocoaPods 组件目录中使用
- 项目根目录有 `.podspec` 文件
- MCP `ios-components` 工具可用且组件已被索引
- 当前分支为 main 或 master（generate/full 模式）

### 通用
- 上传功能需要安装并认证 lark-cli：
  ```bash
  npm install -g @larksuite/cli
  lark-cli config init
  lark-cli auth login --recommend
  ```

## 使用

```bash
# === CocoaPods 组件目录下 ===

# 完整流程（自动检测组件名）
/wk-lark-wiki wiki_node=wikcnXXXX

# 仅生成文档
/wk-lark-wiki mode=generate

# === mcp-ios-components 项目下 ===

# 完整流程
/wk-lark-wiki pods_dir=/path/to/Pods wiki_node=wikcnXXXX

# 处理单个组件
/wk-lark-wiki component=BTBaseKit pods_dir=/path/to/Pods wiki_node=wikcnXXXX

# === 通用 ===

# 仅润色现有文档
/wk-lark-wiki mode=polish

# 仅上传到飞书
/wk-lark-wiki mode=upload wiki_node=wikcnXXXX

# 预览模式（不实际上传）
/wk-lark-wiki mode=full preview=true
```

## 安装

```bash
# 通过 install.sh
./install.sh wk-lark-wiki

# 通过 Plugin Marketplace
/plugin install wk-lark-wiki@yuxilong-skills
```
