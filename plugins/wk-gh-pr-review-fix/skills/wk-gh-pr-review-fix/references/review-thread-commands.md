# Review Thread 命令参考

## 1. 解析当前分支 PR

```bash
gh pr view --json number,url,isDraft,reviewDecision
```

## 2. 获取 thread-aware review 状态

优先使用现成脚本：

```bash
python3 /Users/yuxilong/.codex/plugins/cache/openai-curated/github/fb0a18376bcd9f2604047fbe7459ec5aed70c64b/skills/gh-address-comments/scripts/fetch_comments.py \
  --repo <owner/repo> \
  --pr <number>
```

GraphQL fallback：

```bash
gh api graphql -f query='query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:50) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first:20) {
            nodes {
              id
              databaseId
              body
              author { login }
            }
          }
        }
      }
    }
  }
}' -F owner=<owner> -F repo=<repo> -F number=<number>
```

## 3. 回复 inline review

```bash
gh api repos/<owner>/<repo>/pulls/<pr>/comments/<databaseId>/replies \
  -f body=$'已修复，变更在提交 `<sha>`。\n\n<what changed>\n\n本地已验证：\n- <command>\n- 结果 `<result>`'
```

## 4. Resolve thread

```bash
gh api graphql -f query='mutation($threadId:ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { id isResolved }
  }
}' -F threadId=<thread-id>
```

## 5. 回拉最终状态

```bash
gh pr checks <number>
python3 /Users/yuxilong/.codex/plugins/cache/openai-curated/github/fb0a18376bcd9f2604047fbe7459ec5aed70c64b/skills/gh-address-comments/scripts/fetch_comments.py \
  --repo <owner/repo> \
  --pr <number>
```
