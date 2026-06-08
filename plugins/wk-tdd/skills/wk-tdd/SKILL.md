---
name: wk-tdd
description: |
  iOS/macOS TDD 工作流引导 — 强制先写测试（RED→GREEN→REFACTOR），
  覆盖 Swift Testing / XCTest / OCMock，内置覆盖率验证。
  每个阶段产出可直接运行的代码，不允许跳过 RED 阶段。
---

# WK-TDD — iOS/macOS 测试驱动开发 Skill

## 核心原则

**MANDATORY**: 测试必须先于实现。严禁跳过 RED 阶段直接写实现代码。

```
RED → GREEN → REFACTOR → REPEAT

RED:      写一个会失败的测试（描述期望行为）
GREEN:    写最少的实现代码让测试通过
REFACTOR: 改善代码结构，测试必须保持绿色
REPEAT:   下一个场景/行为继续循环
```

---

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `task` | 是（或自然语言） | — | 要实现的功能描述 |
| `lang` | 否 | `auto` | `swift` / `objc` / `auto`（自动检测） |
| `target` | 否 | — | 被测文件或类名，提升上下文精准度 |
| `coverage` | 否 | `true` | 是否在最终阶段执行覆盖率验证 |
| `phase` | 否 | `start` | `start` / `red` / `green` / `refactor` / `coverage` |

---

## 工作流

### 阶段 0：探索与定位

在开始写测试前：

1. 用 `grep` 或 `codegraph_search` 找到相关类/文件
2. 读取被测类的 public interface（头文件或 Swift 协议）
3. 自动检测测试框架：
   - `import Testing` → Swift Testing
   - `import XCTest` / `.m` 文件 → XCTest + OCMock
   - 既有测试文件同目录 → 跟随项目已有风格
4. 确认测试目标文件命名约定（`<ClassName>Tests.swift` 或 `<ClassName>Tests.m`）

### 阶段 1：RED — 写失败测试

**规则**：
- 测试必须描述**行为**而不是实现细节
- 一次只写一个失败测试（小步前进）
- 运行测试，确认失败原因符合预期（不是编译错误）

**输出格式**：
```
## RED 阶段

### 测试场景
[描述这个测试覆盖什么行为]

### 测试代码
[完整可运行的测试代码]

### 运行命令
[xcodebuild test 命令 或 swift test 命令]

### 预期失败原因
[为什么这个测试应该失败：未实现 / 返回错误值 / 抛出异常]
```

### 阶段 2：GREEN — 最小实现

**规则**：
- 只写让当前测试通过的最少代码
- 不要提前优化，不要实现未被测试覆盖的逻辑
- 运行测试，确认全部通过

**输出格式**：
```
## GREEN 阶段

### 实现代码
[最小实现]

### 运行命令
[同上]

### 预期结果
✅ 所有测试通过
```

### 阶段 3：REFACTOR — 重构

**规则**：
- 消除重复，改善命名，优化结构
- 每次小改动后立即运行测试
- 测试必须始终保持绿色

**重构检查清单**：
- [ ] 命名清晰表达意图
- [ ] 函数职责单一（≤ 40 行）
- [ ] 无重复逻辑
- [ ] 无魔法数字（常量化）
- [ ] 符合项目编码规范

### 阶段 4：COVERAGE — 覆盖率验证

参考 `references/ios-testing-patterns.md` 中的覆盖率运行命令。

**覆盖率目标**：

| 类型 | 最低要求 | 推荐 |
|------|---------|------|
| 普通业务逻辑 | 80% | 90%+ |
| 关键路径（认证/支付/数据安全） | 100% | 100% |
| UI 层（ViewController） | 60% | 70%+ |

覆盖率不达标时，输出未覆盖的具体行/分支，并给出补测方向（不自动生成测试）。

---

## iOS 测试框架选择

### Swift Testing（推荐，Swift 5.9+）

```swift
import Testing

@Test("登录成功返回用户信息")
func loginSuccess() async throws {
    let sut = LoginManager(api: MockAPI())
    let user = try await sut.login(email: "test@example.com", password: "123456")
    #expect(user.email == "test@example.com")
}

@Test("密码错误抛出认证异常")
func loginWrongPassword() async throws {
    let sut = LoginManager(api: MockAPI(shouldFail: true))
    #expect(throws: AuthError.invalidCredentials) {
        try await sut.login(email: "test@example.com", password: "wrong")
    }
}

// 参数化测试
@Test("多种无效邮箱格式均被拒绝", arguments: ["", "notanemail", "@nodomain.com", "no@"])
func rejectsInvalidEmail(email: String) throws {
    #expect(throws: ValidationError.invalidEmail) {
        try LoginManager.validate(email: email)
    }
}
```

**异步确认（替代 XCTestExpectation）**：

```swift
@Test("完成回调在成功后触发")
func completionCalledOnSuccess() async {
    await confirmation { done in
        let sut = UploadService(onComplete: { done() })
        await sut.upload(data: Data())
    }
}
```

**Actor 测试（直接 await，无需额外同步）**：

```swift
@Test("缓存读写一致性")
func cacheRoundTrip() async {
    let cache = MessageCache()
    await cache.store(message: .mock)
    let result = await cache.fetch(id: Message.mock.id)
    #expect(result?.id == Message.mock.id)
}
```

### XCTest（ObjC / 遗留 Swift 代码）

```objc
// XXLoginManagerTests.m
@interface XXLoginManagerTests : XCTestCase
@property (nonatomic, strong) XXLoginManager *sut;
@property (nonatomic, strong) id<XXAPIProtocol> mockAPI;
@end

@implementation XXLoginManagerTests

- (void)setUp {
    [super setUp];
    self.mockAPI = OCMProtocolMock(@protocol(XXAPIProtocol));
    self.sut = [[XXLoginManager alloc] initWithAPI:self.mockAPI];
}

- (void)tearDown {
    self.sut = nil;
    self.mockAPI = nil;
    [super tearDown];
}

- (void)testLogin_withValidCredentials_returnsUser {
    // Arrange
    NSDictionary *mockResponse = @{@"userId": @"123", @"email": @"test@example.com"};
    OCMStub([self.mockAPI loginWithEmail:@"test@example.com"
                               password:@"123456"
                             completion:([OCMArg invokeBlockWithArgs:mockResponse, [NSNull null], nil])]);
    // Act
    XCTestExpectation *exp = [self expectationWithDescription:@"login"];
    [self.sut loginWithEmail:@"test@example.com" password:@"123456" completion:^(XXUser *user, NSError *error) {
        // Assert
        XCTAssertNotNil(user);
        XCTAssertNil(error);
        XCTAssertEqualObjects(user.email, @"test@example.com");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testLogin_withWrongPassword_returnsAuthError {
    NSError *authError = [NSError errorWithDomain:XXAuthErrorDomain
                                             code:XXAuthErrorInvalidCredentials
                                         userInfo:nil];
    OCMStub([self.mockAPI loginWithEmail:OCMOCK_ANY
                               password:OCMOCK_ANY
                             completion:([OCMArg invokeBlockWithArgs:[NSNull null], authError, nil])]);

    XCTestExpectation *exp = [self expectationWithDescription:@"error"];
    [self.sut loginWithEmail:@"test@example.com" password:@"wrong" completion:^(XXUser *user, NSError *error) {
        XCTAssertNil(user);
        XCTAssertEqual(error.code, XXAuthErrorInvalidCredentials);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}
```

---

## 必须覆盖的边界场景

写完 happy path 测试后，检查以下场景是否有测试：

| 场景 | 示例 |
|------|------|
| nil / null 输入 | `login(email: nil)` |
| 空字符串 | `login(email: "")` |
| 边界值 | 最大长度 / 最小值 / 零值 |
| 错误路径 | 网络超时、服务器 500、解析失败 |
| 并发 | 多线程同时写缓存、重复触发 |
| 状态未初始化 | 在 setup 完成前调用方法 |
| 大数据量 | 10000 条消息列表渲染 |

---

## 质量检查清单

完成 TDD 循环后验证：

- [ ] 所有 public 方法有对应测试
- [ ] 错误路径（失败/超时/nil）有测试
- [ ] 边界值和边缘场景有测试
- [ ] 外部依赖（网络/数据库/系统 API）用 Mock/Stub 隔离
- [ ] 每个测试相互独立（无共享可变状态）
- [ ] 测试命名清晰表达意图（`test<行为>_<前置条件>_<预期结果>`）
- [ ] 覆盖率 ≥ 80%（关键路径 100%）
- [ ] 没有跳过/禁用的测试（`.skip` / `xtestXxx`）

---

## 详细参考

- iOS 测试框架速查 → `references/ios-testing-patterns.md`
- TDD 反模式与陷阱 → `references/tdd-antipatterns.md`
