---
paths:
  - "**/*.h"
  - "**/*.m"
  - "**/*.mm"
---
# Objective-C Testing

> This file extends [common/testing.md](../common/testing.md) with Objective-C specific content.

## Framework

Use **XCTest** for all Objective-C tests. Use **OCMock** for mocking.

## Test File Naming

`<ClassName>Tests.m` — one test file per class under test:

```
XXUserManagerTests.m
XXNetworkClientTests.m
```

## Test Structure

```objc
@interface XXUserManagerTests : XCTestCase
@property (nonatomic, strong) XXUserManager *sut; // system under test
@end

@implementation XXUserManagerTests

- (void)setUp {
    [super setUp];
    self.sut = [[XXUserManager alloc] init];
}

- (void)tearDown {
    self.sut = nil;
    [super tearDown];
}

- (void)testFetchUser_withValidId_returnsUser {
    XXUser *user = [self.sut fetchUserWithId:@"123"];
    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.userId, @"123");
}

@end
```

## Mocking with OCMock

```objc
- (void)testService_callsDelegate {
    id mockDelegate = OCMProtocolMock(@protocol(XXServiceDelegate));
    self.sut.delegate = mockDelegate;

    [self.sut performAction];

    OCMVerify([mockDelegate serviceDidFinish:self.sut]);
}
```

## Async Testing

Use `XCTestExpectation` for async operations:

```objc
- (void)testAsyncFetch {
    XCTestExpectation *exp = [self expectationWithDescription:@"fetch"];
    [self.sut fetchDataWithCompletion:^(NSArray *items, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue(items.count > 0);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}
```

## Coverage

```bash
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath TestResults.xcresult
xcrun xcresulttool get --path TestResults.xcresult --format json
```
