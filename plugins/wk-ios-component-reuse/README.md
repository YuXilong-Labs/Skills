# wk-ios-component-reuse

iOS 组件库复用工作流 — 选型、实现、审查、迁移阶段强制执行"先检索组件再行动"。

## 前置要求

MCP `ios-components` server 已连接。

## 4 种模式

| 模式 | 说明 |
|------|------|
| `selection` | 组件选型评估，输出候选矩阵与主/备方案 |
| `implementation` | 复用优先实现，先检索再编码（默认模式） |
| `review` | PR 组件复用审查，输出证据链与严重级别 |
| `migration` | 重复实现迁移，输出映射表与分批改造计划 |

## 特点

- JSON-first 多轮检索策略，小步收敛
- 所有结论必须附带证据最小集（检索 + API + 佐证）
- 完整的失败恢复与回退路径
- 结构化输出契约，可审计、可追溯

## 使用

```bash
# 组件选型
/wk-ios-component-reuse mode=selection requirement=做一个带分页列表的页面

# 复用优先实现
/wk-ios-component-reuse mode=implementation requirement=实现头像圆角缓存加载

# PR 审查
/wk-ios-component-reuse mode=review requirement=检查PR是否有自定义图片下载器

# 迁移计划
/wk-ios-component-reuse mode=migration requirement=把自定义缓存迁移到基础组件

# 自然语言
/wk-ios-component-reuse 实现上传功能，不要重复造轮子
```
