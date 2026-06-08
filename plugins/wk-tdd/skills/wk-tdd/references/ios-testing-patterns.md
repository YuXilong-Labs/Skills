# iOS 测试模式速查

## 运行测试命令

### Swift Package（SwiftPM）

```bash
# 运行所有测试
swift test

# 运行并输出覆盖率
swift test --enable-code-coverage

# 运行指定测试目标
swift test --filter LoginManagerTests

# 运行单个测试
swift test --filter LoginManagerTests/loginSuccess
```

### Xcode 工程

```bash
# 运行测试（优先用 wk-xcodebuild 包装器）
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath TestResults.xcresult

# 提取覆盖率
xcrun xcresulttool get --path TestResults.xcresult --format json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d['metrics']['testsCount'])"
```

---

## Swift Testing 速查

### 基本结构

```swift
import Testing

// 函数级测试
@Test("描述行为")
func behaviorName() throws {
    let sut = MyClass()
    #expect(sut.value == 42)
}

// 结构体组织测试套件
struct LoginManagerTests {
    let sut: LoginManager
    let mockAPI: MockAPI

    init() {
        mockAPI = MockAPI()
        sut = LoginManager(api: mockAPI)
    }

    @Test func loginSuccessReturnsUser() async throws { ... }
    @Test func loginFailureThrowsError() async throws { ... }
}
```

### 断言

```swift
#expect(value == expected)                   // 相等
#expect(value != unexpected)                 // 不等
#expect(collection.isEmpty)                  // 空
#expect(value > 0)                           // 比较
#expect(throws: SomeError.case) { try fn() } // 异常
try #require(optional)                       // 解包，nil 则中止测试
```

### 参数化

```swift
@Test(arguments: [1, 2, 3])
func positiveNumbers(n: Int) { #expect(n > 0) }

// 多维参数
@Test(arguments: zip(inputs, expected))
func transform(input: String, expected: String) {
    #expect(MyTransformer.run(input) == expected)
}
```

### Traits

```swift
// 只在 CI 运行
@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] != nil))
func onlyOnCI() async { ... }

// 关联 Bug
@Test(.bug("https://github.com/org/repo/issues/42"))
func regressionTest() { ... }

// 超时
@Test(.timeLimit(.minutes(1)))
func slowOperation() async throws { ... }

// 跳过（临时，附说明）
@Test(.disabled("等待 API 稳定后启用"))
func pendingTest() { ... }
```

### 异步 Confirmation

```swift
// 替代 XCTestExpectation
@Test func callbackFired() async {
    await confirmation { done in
        let sut = Service(completion: { done() })
        await sut.start()
    }
}

// 期望多次触发
@Test func notifiedThreeTimes() async {
    await confirmation(expectedCount: 3) { fire in
        let sut = Counter(onChange: { fire() })
        await sut.increment(times: 3)
    }
}
```

---

## XCTest 速查（ObjC / 遗留 Swift）

### 文件命名约定

```
被测类：XXUserManager
测试文件：XXUserManagerTests.m
```

### 标准结构

```objc
@interface XXFooTests : XCTestCase
@property (nonatomic, strong) XXFoo *sut;  // system under test
@end

@implementation XXFooTests

- (void)setUp {
    [super setUp];
    self.sut = [[XXFoo alloc] init];
}

- (void)tearDown {
    self.sut = nil;
    [super tearDown];
}

// 命名规范：test<行为>_<条件>_<预期>
- (void)testProcess_withValidInput_returnsResult { ... }
- (void)testProcess_withNilInput_throwsException { ... }

@end
```

### 断言

```objc
XCTAssertEqual(actual, expected);
XCTAssertEqualObjects(actualObj, expectedObj);
XCTAssertNil(value);
XCTAssertNotNil(value);
XCTAssertTrue(condition);
XCTAssertFalse(condition);
XCTAssertThrows(expression);
XCTAssertThrowsSpecific(expression, ExceptionClass);
```

### 异步测试

```objc
- (void)testAsyncOperation {
    XCTestExpectation *exp = [self expectationWithDescription:@"operation completes"];

    [self.sut doAsyncWork:^(id result, NSError *error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}
```

---

## OCMock 速查

### 协议 Mock

```objc
id<XXNetworkProtocol> mockNetwork = OCMProtocolMock(@protocol(XXNetworkProtocol));
// 注入
self.sut = [[XXService alloc] initWithNetwork:mockNetwork];
```

### 类 Mock

```objc
XXDatabaseManager *mockDB = OCMClassMock([XXDatabaseManager class]);
```

### Stub 返回值

```objc
OCMStub([mockNetwork fetchURL:OCMOCK_ANY completion:
    ([OCMArg invokeBlockWithArgs:responseData, [NSNull null], nil])]);
```

### Stub 抛出错误

```objc
NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain
                                            code:NSURLErrorTimedOut
                                        userInfo:nil];
OCMStub([mockNetwork fetchURL:OCMOCK_ANY completion:
    ([OCMArg invokeBlockWithArgs:[NSNull null], networkError, nil])]);
```

### 验证调用

```objc
// 验证方法被调用一次
OCMVerify([mockNetwork fetchURL:[OCMArg isEqual:@"https://api.example.com"] completion:OCMOCK_ANY]);

// 验证从未调用
OCMReject([mockDB saveData:OCMOCK_ANY]);
[self.sut performAction];
OCMVerifyAll(mockDB);
```

### 部分 Mock（慎用）

```objc
XXAnalyticsManager *partialMock = OCMPartialMock(self.sut.analyticsManager);
OCMStub([partialMock trackEvent:OCMOCK_ANY]);
// ... 测试完成后
[partialMock stopMocking];
```

---

## Mock 设计原则

1. **只 Mock 外部依赖**（网络、数据库、系统 API、第三方 SDK）
2. **用协议隔离**，被测类依赖协议而非具体实现，便于注入 Mock
3. **不 Mock 被测类本身**（partial mock 是代码设计问题的信号）
4. **Stub 精确到调用参数**，避免 `OCMOCK_ANY` 滥用掩盖逻辑错误

```objc
// 推荐：依赖注入 + 协议
@interface XXSyncService : NSObject
- (instancetype)initWithNetwork:(id<XXNetworkProtocol>)network
                       database:(id<XXDatabaseProtocol>)database;
@end

// 测试中注入 Mock
XXSyncService *sut = [[XXSyncService alloc]
    initWithNetwork:mockNetwork
           database:mockDatabase];
```

---

## 测试目录约定

```
MyApp/
├── Sources/
│   └── Features/
│       └── Login/
│           ├── LoginManager.swift        ← 被测类
│           └── LoginManager+Protocol.swift
└── Tests/
    └── Unit/
        └── Login/
            ├── LoginManagerTests.swift   ← 测试文件（紧邻被测类对应目录）
            └── Mocks/
                └── MockLoginAPI.swift    ← 测试专用 Mock
```

ObjC 工程：
```
MyApp/
├── Classes/Login/
│   ├── XXLoginManager.h
│   └── XXLoginManager.m
└── Tests/Unit/Login/
    ├── XXLoginManagerTests.m
    └── Mocks/
        └── XXMockAPIClient.h / .m
```
