---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Swift specific content.

## Formatting

- **SwiftFormat** for auto-formatting, **SwiftLint** for style enforcement
- `swift-format` is bundled with Xcode 16+ as an alternative

## Immutability

- Prefer `let` over `var` — define everything as `let` and only change to `var` if the compiler requires it
- Use `struct` with value semantics by default; use `class` only when identity or reference semantics are needed

## Naming

Follow [Apple API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/):

- Clarity at the point of use — omit needless words
- Name methods and properties for their roles, not their types
- Use `static let` for constants over global constants

## Error Handling

Use typed throws (Swift 6+) and pattern matching:

```swift
func load(id: String) throws(LoadError) -> Item {
    guard let data = try? read(from: path) else {
        throw .fileNotFound(id)
    }
    return try decode(data)
}
```

## Concurrency

Enable Swift 6 strict concurrency checking. Prefer:

- `Sendable` value types for data crossing isolation boundaries
- Actors for shared mutable state
- Structured concurrency (`async let`, `TaskGroup`) over unstructured `Task {}`

## Swift 6.2 Approachable Concurrency

Default single-threaded execution model — functions run on the caller's actor unless opted out:

- `nonisolated(nonsending)` is the new default for function declarations — no annotation needed
- Use `@concurrent` to explicitly opt into parallel execution when safe:

```swift
// Runs on caller's actor (default in 6.2)
func processData(_ data: Data) async -> Result { ... }

// Explicitly parallel — must be Sendable-safe
@concurrent
func compress(_ data: Data) async -> Data { ... }
```

- Enable with: `swift build -enable-experimental-feature DefaultIsolationNonIsolated`

## Type Erasure & Opaque Types

- Prefer `any Protocol` for existentials (storage, heterogeneous collections)
- Prefer `some Protocol` for opaque return types (preserves concrete type identity)
- Prefer `some Protocol` in parameters when the concrete type matters for performance

```swift
func fetch(from source: any DataSource) async throws -> some View {
    // `any` for input flexibility, `some` for output type identity
}
```

## Comments

Every class, property, public method, and non-trivial logic block must have a `///` doc comment. Use `//` for inline logic notes:

```swift
/// 红包弹窗视图
class RedPacketView: UIView {

    /// 红包icon
    private let iconView = UIImageView()

    /// 金额标签
    private let amountLabel = UILabel()

    /// 显示红包弹窗
    /// - Parameters:
    ///   - amount: 红包金额（单位：分）
    ///   - animated: 是否带动画
    func show(amount: Int, animated: Bool) {
        // 金额为0时不展示弹窗
        guard amount > 0 else { return }

        // 先更新UI再执行动画，避免闪烁
        amountLabel.text = "\(amount / 100)"
        performShowAnimation(animated: animated)
    }
}
```

Enum case comments:

```swift
/// 布局模式
enum LayoutMode {
    /// 不支持
    case none
    /// 网格布局
    case grid
    /// 列表布局
    case list
}
```

- `internal` by default — no annotation needed
- Mark `public` explicitly at API boundaries (frameworks, SPM targets)
- Use `package` access (Swift 5.9+) for cross-module visibility within a package
- Prefer `private` over `fileprivate` unless file-scope sharing is required

## Auto Layout Constraints

Use **SnapKit** for constraint setup. Always use `leading`/`trailing` for horizontal constraints — never `left`/`right` (RTL language support):

```swift
// CORRECT
contentView.snp.makeConstraints { make in
    make.leading.equalToSuperview().offset(16)
    make.trailing.equalToSuperview().offset(-16)
}

// WRONG — breaks RTL layout
contentView.snp.makeConstraints { make in
    make.left.equalToSuperview().offset(16)
    make.right.equalToSuperview().offset(-16)
}
```
