---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Testing

> This file extends [common/testing.md](../common/testing.md) with Swift specific content.

## Framework

Use **Swift Testing** (`import Testing`) for new tests. Use `@Test` and `#expect`:

```swift
@Test("User creation validates email")
func userCreationValidatesEmail() throws {
    #expect(throws: ValidationError.invalidEmail) {
        try User(email: "not-an-email")
    }
}
```

## Test Isolation

Each test gets a fresh instance — set up in `init`, tear down in `deinit`. No shared mutable state between tests.

## Parameterized Tests

```swift
@Test("Validates formats", arguments: ["json", "xml", "csv"])
func validatesFormat(format: String) throws {
    let parser = try Parser(format: format)
    #expect(parser.isValid)
}
```

## Test Traits

Use traits for conditional execution, bug tracking, and timeouts:

```swift
@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] != nil))
func onlyOnCI() async { ... }

@Test(.bug("https://github.com/org/repo/issues/42"), .timeLimit(.minutes(2)))
func longRunningOperation() async throws { ... }
```

## Async Confirmation

Use `confirmation` for async expectations (replaces XCTestExpectation):

```swift
@Test func notifiesOnCompletion() async {
    await confirmation { done in
        let service = Service(onComplete: { done() })
        await service.start()
    }
}
// Use confirmation(expectedCount: 3) for multiple fulfillments
```

## Testing Actors

Await actor methods directly — each `await` is a suspension point, tests naturally serialize:

```swift
@Test func cacheRoundTrip() async {
    let cache = Cache<String, Int>()
    await cache.set("key", value: 42)
    #expect(await cache.get("key") == 42)
}
```

## Snapshot Testing

Use `swift-snapshot-testing` for UI regression. Store snapshots in `__Snapshots__/` next to test files. Never auto-update in CI.

```swift
assertSnapshot(of: ProfileView(user: .mock), as: .image(layout: .device(config: .iPhone15Pro)))
```

## Coverage

Run `swift test --enable-code-coverage`. See skill: `swift-protocol-di-testing` for DI and mock patterns.
