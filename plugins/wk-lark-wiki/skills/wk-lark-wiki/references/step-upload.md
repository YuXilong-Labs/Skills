# 飞书上传详细步骤（update-or-create）

上传润色后的文档（优先 `docs/api/polished/`，若不存在则用 `docs/api/`）。

## 5.1 加载 wiki 映射

```bash
cat docs/api/.wiki-mapping.json 2>/dev/null || echo "{}"
```

## 5.2 逐文件上传（update-or-create 逻辑）

对每个待上传的 .md 文件，按以下决策流程执行：

```
1. 从 .wiki-mapping.json 查找该组件的 doc_id

2. 如果有 doc_id（曾经上传过）：
   → 读取文件内容到临时文件
   → 执行：lark-cli docs +update --doc <doc_id> --mode overwrite --markdown-file <tmp_file> --as user
   → 如果 update 成功 → 记录结果，继续下一个
   → 如果 update 失败（文档已被删除等）→ 清除映射，进入步骤 3

3. 如果没有映射（首次上传或映射失效）：
   → 执行搜索：lark-cli docs +search --query "<组件名>" --as user
   → 解析搜索结果，查找 title 完全匹配的文档
   → 如果找到匹配文档：
     → 提取 doc_id
     → 执行：lark-cli docs +update --doc <doc_id> --mode overwrite --markdown-file <tmp_file> --as user
   → 如果未找到匹配：
     → 执行：lark-cli docs +create --title "<title>" --markdown-file <tmp_file> --wiki-node <wiki_node> --as user
     → 从创建结果中提取 doc_id

4. 更新 .wiki-mapping.json 中该组件的 doc_id 和 last_uploaded
```

**lark-cli +update 的 markdown 传递方式：**
- 短内容（< 5000 字符）：`--markdown <content>`
- 长内容：写入临时文件，使用 `--markdown-file <tmp_file>`

## 5.3 保存 wiki 映射

使用 Write 工具更新 `docs/api/.wiki-mapping.json`：

```json
{
  "wiki_node": "wikcnXXXX",
  "updated_at": "2026-04-01T12:00:00",
  "mappings": {
    "BTBaseKit": {
      "doc_id": "doccnYYYY",
      "doc_url": "https://xxx.feishu.cn/wiki/...",
      "title": "BTBaseKit-底层基类、工具类",
      "last_uploaded": "2026-04-01T12:00:00"
    }
  }
}
```

## 5.4 预览模式

`preview=true` 时，对每个文件输出将要执行的操作（create / update + doc_id + title），但不执行任何 lark-cli 命令。
