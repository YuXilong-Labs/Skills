# 增量文档生成详细步骤

## 2.1 源码增量检测

计算源码文件 hash，与上次生成时的记录比对：

**CocoaPods 组件上下文：**
```bash
# 排除 Example/ Pods/ .git/ DerivedData/ 目录
find . \( -name "*.h" -o -name "*.m" -o -name "*.mm" -o -name "*.swift" \) \
    ! -path "*/Example/*" ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/DerivedData/*" \
    -exec md5 -r {} \; | sort
```

**mcp-ios-components 上下文：**
```bash
# 计算指定组件的源码 hash
find <pods_dir>/<component> -name "*.h" -o -name "*.m" -o -name "*.swift" | \
    xargs md5 -r | sort
```

与 `docs/api/.source-checksums.json` 比对：
- hash 不同 → 源文件有变更，对应类文档需要重新生成
- 新文件 → 需要生成
- hash 相同 → 跳过

> **首次运行**（无 `.source-checksums.json`）→ 全量生成所有文档。

## 2.2 文档生成 — mcp-ios-components 路径

使用 Bash 工具执行生成脚本。输出重定向到临时文件：

```bash
python tools/generate_api_docs.py --pods-dir <pods_dir> [--component <name>] [--ai-fill] \
    2>&1 | tee /tmp/wk-lark-wiki-gen.log | tail -30
```

## 2.3 文档生成 — CocoaPods 组件路径

Claude Code 使用 MCP ios-components 工具直接生成文档：

1. **获取 API 列表**：调用 `get_component_api(component_name)`，获取完整公开 API（按文件分组）
2. **逐类获取详情**：对每个类/协议调用 `get_class_detail(component_name, classname)`
   - 批量调用：每条消息中并行发出多个 `get_class_detail` 调用（提升效率）
3. **补充实现细节**：对复杂初始化器、枚举值、核心方法调用 `read_source(component_name, file, start, end)` 获取源码
4. **组装文档**：按 [lark-doc-template.md](lark-doc-template.md) 模板结构组装 Markdown
5. **写入文件**：使用 Write 工具写入 `docs/api/<ComponentName>.md`

**关键约束：**
- 排除 `Example/` 目录下的所有文件
- 只处理公开 API（public header 中的声明）
- 仅对增量检测标记为"需重新生成"的类执行上述流程

## 2.4 生成文件目录架构图

每份组件文档必须在 `# 组件名` 和摘要之后、`## 快速开始` 之前包含一个 `## 文件目录` 章节。

使用 Bash 工具获取目录结构：
```bash
# CocoaPods 组件
tree -I "Example|Pods|.git|DerivedData|__pycache__" --dirsfirst -L 3 --charset ascii

# mcp-ios-components（指定组件目录）
tree <pods_dir>/<component> -I "Example|.git" --dirsfirst -L 3 --charset ascii
```

**文件目录格式要求：**
- 只展示源文件（`.h`、`.m`、`.mm`、`.swift`）和关键资源目录
- 每个文件/目录后用 `# 注释` 说明用途（从文件名、头部注释或内容推断）
- 目录深度最多 3 层，超过用 `...` 省略
- 空目录不展示

示例：
```
## 文件目录

```
BTBaseKit/
├── Classes/
│   ├── Core/
│   │   ├── BTBaseObject.h          # 基类定义，所有组件的根类
│   │   ├── BTBaseObject.m          # 基类实现，KVO/通知等基础能力
│   │   └── BTSingleton.h           # 单例宏定义
│   ├── Utils/
│   │   ├── BTStringUtils.h         # 字符串工具（加密、截取、校验）
│   │   └── BTDeviceInfo.h          # 设备信息采集（型号、系统、网络）
│   └── Categories/
│       ├── NSString+BTExtension.h  # NSString 扩展（URL 编码、MD5）
│       └── UIView+BTLayout.h       # UIView 布局便捷方法
└── BTBaseKit.podspec
```
```

## 2.5 更新源码 checksums

生成完成后，使用 Write 工具写入 `docs/api/.source-checksums.json`：

```json
{
  "updated_at": "2026-04-01T12:00:00",
  "context": "cocoapods-component",
  "component": "BTBaseKit",
  "files": {
    "Classes/Core/BTBaseObject.h": "a1b2c3d4...",
    "Classes/Utils/BTStringUtils.h": "e5f6a7b8..."
  }
}
```

**生成后确认：**
1. 列出 `docs/api/` 下新生成/更新的 .md 文件
2. 报告：生成 N 个、跳过 M 个（未变更）、总 API 数
