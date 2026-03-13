# 核心工作流（所有模式共享）

## 工具调用流程

### 0. 工具确认（首次接入时）

```
get_tool_docs(tool_name="search_component", format="json")
get_tool_docs(tool_name="find_usage_example", format="json")
```

仅在首次接入或工具语义不清时执行，后续可跳过。

### 1. 需求拆解

将需求拆成能力清单：
- 网络（HTTP / WebSocket / 上传下载）
- UI 组件（弹窗 / Toast / 空态 / 刷新 / 列表 / 骨架屏）
- 图片处理（缩放 / 裁剪 / 圆角 / 滤镜 / 缓存）
- 存储（缓存 / 数据库 / 文件 / Keychain）
- 工具类（日期 / 字符串 / 加密 / JSON / 日志）
- 路由 / 埋点 / 监控

### 2. 多轮检索（JSON-first）

**默认参数：** `search_component(format="json", limit=5)`

**检索轮次（至少 3 轮）：**
1. 中文语义词（如"圆角""弹窗""上传"）
2. 英文同义词（如"corner""alert""upload"）
3. 类名/类型词（如"UIImage""UIView""URLSession"）
4. 动词 + 类名组合（如"clip image""cache download"）
5. 必要时用 `kind` 收敛（如 `kind="method"`）

**收敛原则：**
- 小步多轮，不建议一开始就 `limit=50+`
- 结果偏离时用更窄关键词或 `kind` 限制
- 仅在小 `limit` 下命中太少时扩大到 `10-20`

### 3. 候选验证

按以下顺序确认候选组件：

| 步骤 | 工具 | 目的 |
|------|------|------|
| 1 | `get_component_api(component_name)` | 确认公开 API 范围 |
| 2 | `get_class_detail(component_name, classname)` | 确认关键类/协议入口 |
| 3 | `find_usage_example(component_name)` | 查看真实使用方式 |
| 4 | `read_source(component_name, file, start, end)` | 小范围验证（20-40 行） |
| 5 | `audit_component_api_quality(component_name)` | 可选：评估命名/注释质量 |

**验证原则：**
- 仅在需要确认实现细节或边界条件时使用 `read_source`
- `api_only` 组件无法 `read_source` 时，用 `get_component_api` + `get_class_detail` + `find_usage_example` 替代
- 不虚构 API 签名，证据不足时向用户说明

### 4. 结构化输出

每种模式有各自的输出契约，但所有输出必须包含：
- 检索证据（关键词 + 命中结果）
- API 证据（`get_component_api` 确认的接口）
- 结论与理由

## 证据最小集

每个关键结论至少包含：

| 证据类型 | 必须 | 来源 |
|----------|------|------|
| 检索命中 | 是 | `search_component` 关键词 + 命中项 |
| API 确认 | 是 | `get_component_api` 关键 API |
| 使用佐证 | 是 | `get_class_detail` / `read_source` / `find_usage_example` 任一 |

## 失败恢复与回退路径

### 无命中

1. 追加同义词、类名词再搜（至少补 2 轮）
2. 记录已检索关键词列表
3. 明确输出"已检索范围 + 未命中"
4. 仅在穷尽检索后给最小新增实现建议（边界清楚，不重写基础库）

### 命中过多但不确定

1. 用更窄关键词（类名 + 动词）
2. 使用 `kind` 限制（如 `method` / `interface`）
3. 对前 2-3 个候选做 `get_component_api` 对比，不盲选

### `api_only` 限制

1. 记录访问限制
2. 使用 `get_component_api` + `get_class_detail` + `find_usage_example` 替代
3. 在结论中标注"证据受限"与未确认项

### 工具缺失或返回异常

1. 优先调用 `get_tool_docs` 确认参数/格式
2. 降级为 text 格式检索并说明限制
3. 不可虚构 API 签名，必要时向用户要更多上下文
