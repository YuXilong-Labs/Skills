---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Patterns

> This file extends [common/patterns.md](../common/patterns.md) with Swift specific content.

## Protocol-Oriented Design

Define small, focused protocols. Use protocol extensions for shared defaults:

```swift
protocol Repository: Sendable {
    associatedtype Item: Identifiable & Sendable
    func find(by id: Item.ID) async throws -> Item?
    func save(_ item: Item) async throws
}
```

## Value Types

- Use structs for data transfer objects and models
- Use enums with associated values to model distinct states:

```swift
enum LoadState<T: Sendable>: Sendable {
    case idle, loading, loaded(T), failed(Error)
}
```

## Actor Pattern

Use actors for shared mutable state instead of locks or dispatch queues:

```swift
actor Cache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]
    func get(_ key: Key) -> Value? { storage[key] }
    func set(_ key: Key, value: Value) { storage[key] = value }
}
```

## Dependency Injection

Inject protocols with default parameters — production uses defaults, tests inject mocks. Use SwiftUI `@Environment` with `@Entry` for view-tree DI:

```swift
extension EnvironmentValues {
    @Entry var apiClient: any APIClient = LiveAPIClient()
}
```

## @Observable State Management (iOS 17+)

Prefer `@Observable` macro over `ObservableObject` — automatic fine-grained tracking, no `@ObservedObject` needed. Use `@Bindable` for two-way bindings.

```swift
@Observable final class AppState {
    var user: User?
    var isLoading = false
}
```

## SwiftUI Navigation

Use `NavigationStack` with `NavigationPath`. Define routes as `Hashable` enums per feature module, map with `.navigationDestination(for:)`.

```swift
@Observable final class Router {
    var path = NavigationPath()
    func push<V: Hashable>(_ value: V) { path.append(value) }
}
```

## iOS 26 Liquid Glass

Apply glass material for system-integrated UI: `.glassEffect(.regular.interactive)`. Use `.regular` for containers, `.bar` for toolbars. Never place glass on glass — flatten hierarchy.

## References

See skill: `swift-concurrency-6-2` for approachable concurrency patterns.
See skill: `liquid-glass-design` for iOS 26 glass material system.
See skill: `swift-actor-persistence` for actor-based persistence patterns.
See skill: `swift-protocol-di-testing` for protocol-based DI and testing.
