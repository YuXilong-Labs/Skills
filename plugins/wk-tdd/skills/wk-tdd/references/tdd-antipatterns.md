# TDD 反模式与常见陷阱

## 反模式清单

### ❌ 1. 跳过 RED 阶段（最常见）

```
❌ 错误顺序：实现 → 写测试（事后补测试）
✅ 正确顺序：测试（失败）→ 实现 → 重构
```

事后补的测试倾向于覆盖已有实现路径，而不是验证期望行为。

---

### ❌ 2. 测试实现细节而非行为

```swift
// ❌ 测试内部状态（脆弱，重构后即失效）
#expect(sut._internalCache.count == 1)
#expect(sut.isNetworkCallPending == true)

// ✅ 测试可观察行为
#expect(sut.cachedUserCount == 1)
let user = try await sut.fetchUser(id: "123")
#expect(user.name == "Alice")
```

---

### ❌ 3. 一个测试断言太多（掩盖失败原因）

```swift
// ❌ 一个测试验证了太多东西
@Test func loginFlow() async throws {
    let user = try await sut.login(email: "a@b.com", password: "123")
    #expect(user.id == "1")
    #expect(user.email == "a@b.com")
    #expect(user.isAdmin == false)
    #expect(sut.currentSession != nil)
    #expect(mockAnalytics.lastEvent == "login_success")
}

// ✅ 每个测试只验证一件事
@Test func loginReturnsCorrectUser() async throws {
    let user = try await sut.login(email: "a@b.com", password: "123")
    #expect(user.email == "a@b.com")
}

@Test func loginCreatesSession() async throws {
    _ = try await sut.login(email: "a@b.com", password: "123")
    #expect(sut.currentSession != nil)
}
```

---

### ❌ 4. 测试间共享可变状态

```swift
// ❌ 类变量在测试间共享，执行顺序不同结果就不同
struct SomeTests {
    static var sharedManager = UserManager()  // 危险！

    @Test func testA() { Self.sharedManager.add(user: .mock) }
    @Test func testB() { #expect(Self.sharedManager.count == 0) }  // 可能受 testA 影响
}

// ✅ 每个测试自己初始化
struct SomeTests {
    @Test func testA() {
        let manager = UserManager()
        manager.add(user: .mock)
        #expect(manager.count == 1)
    }

    @Test func testB() {
        let manager = UserManager()
        #expect(manager.count == 0)
    }
}
```

---

### ❌ 5. Mock 过度（Mock 了被测类自身的逻辑）

```objc
// ❌ 把被测类的核心方法也 Mock 了，测不到真实逻辑
id partialMock = OCMPartialMock(self.sut);
OCMStub([partialMock calculateScore]).andReturn(100);
// 现在测的是 Mock 行为，不是真实代码
```

如果需要 partial mock 才能测，通常是设计问题：职责不单一，需要重构拆分。

---

### ❌ 6. 用真实网络/数据库（测试不稳定）

```swift
// ❌ 依赖真实外部服务，网络抖动就失败
@Test func fetchUser() async throws {
    let sut = UserService()  // 内部直接用真实 URLSession
    let user = try await sut.fetch(id: "123")
    #expect(user.name != nil)
}

// ✅ 注入 Mock，隔离外部依赖
@Test func fetchUser() async throws {
    let mockSession = MockURLSession(responseData: mockUserJSON)
    let sut = UserService(session: mockSession)
    let user = try await sut.fetch(id: "123")
    #expect(user.name == "Alice")
}
```

---

### ❌ 7. 测试命名含糊

```objc
// ❌ 不知道测什么
- (void)testLogin { }
- (void)testFetch { }
- (void)test1 { }

// ✅ 命名 = 文档
- (void)testLogin_withValidCredentials_returnsAuthenticatedUser { }
- (void)testLogin_withExpiredToken_throwsTokenExpiredError { }
- (void)testFetchMessages_whenOffline_returnsLocalCache { }
```

---

### ❌ 8. 不运行测试确认 RED/GREEN

TDD 的关键是**亲眼看到**测试从红变绿：

1. 写完测试 → **必须运行** → 看到失败（不是编译错误，是断言失败）
2. 写完实现 → **必须运行** → 看到全部通过

跳过运行步骤，失去了 TDD 给你的快速反馈信号。

---

### ❌ 9. 滥用 `.skip` / `xtestXxx`

```swift
// ❌ 用 .disabled 掩盖未完成的测试
@Test(.disabled("以后再修"))
func importantScenario() { }
```

临时 skip 可接受，但必须有跟踪（附 Bug 链接），不允许长期遗留。

```swift
// ✅ 附带跟踪
@Test(.disabled("JIRA-1234：等 API 稳定后启用"))
func pendingTest() { }
```

---

## TDD 的正确节奏

```
小步快跑，每步 < 5 分钟：

1. 写一个最简单的失败测试（30 秒）
2. 运行，确认红（10 秒）
3. 写最少代码让它通过（1-3 分钟）
4. 运行，确认绿（10 秒）
5. 小重构（1 分钟）
6. 运行，确认仍绿（10 秒）
7. 回到第 1 步

节奏乱掉的信号：
- 30 分钟还没让一个测试变绿 → 步子太大，拆分场景
- 重构后测试挂了很多 → 改动太多，还原再小步重构
```

---

## 何时可以不严格 TDD

以下情况可以先写实现后补测试（但补测试不可跳过）：

- **探索性代码**（Spike）：验证技术可行性，跑通后必须删掉重写（TDD）
- **纯 UI 布局**：只有视觉，无逻辑分支
- **第三方集成 Demo**：学习 API 用法，确认后重写

**不可免除 TDD 的场景**：
- 任何包含条件判断的业务逻辑
- 状态机
- 数据转换/计算
- 网络/缓存策略
- 安全/认证逻辑
