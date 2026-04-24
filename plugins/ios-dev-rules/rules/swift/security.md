---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Security

> This file extends [common/security.md](../common/security.md) with Swift specific content.

## Secret Management

- Use **Keychain Services** for sensitive data (tokens, passwords, keys) — never `UserDefaults`
- Use environment variables or `.xcconfig` files for build-time secrets
- Never hardcode secrets in source — decompilation tools extract them trivially

```swift
let apiKey = ProcessInfo.processInfo.environment["API_KEY"]
guard let apiKey, !apiKey.isEmpty else {
    fatalError("API_KEY not configured")
}
```

## Transport Security

- App Transport Security (ATS) is enforced by default — do not disable it
- Use certificate pinning for critical endpoints
- Validate all server certificates

## Input Validation

- Sanitize all user input before display to prevent injection
- Use `URL(string:)` with validation rather than force-unwrapping
- Validate data from external sources (APIs, deep links, pasteboard) before processing

## Data Protection API

Apply file protection levels for data at rest:

```swift
try data.write(to: url, options: [.completeFileProtection])
// Or set on directory:
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.complete],
    ofItemAtPath: path
)
```

- `.complete` — accessible only when device is unlocked (default for most sensitive data)
- `.completeUnlessOpen` — for files that need background write access
- Never use `.none` for user data

## Secure Enclave & Biometrics

Use Secure Enclave for biometric-gated keys — keys never leave hardware:

```swift
let access = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet], nil
)!
let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    kSecPrivateKeyAttrs as String: [kSecAttrAccessControl as String: access]
]
```

## Network.framework TLS

Configure TLS parameters explicitly for custom connections:

```swift
let tlsOptions = NWProtocolTLS.Options()
sec_protocol_options_set_min_tls_protocol_version(
    tlsOptions.securityProtocolOptions, .TLSv13
)
let params = NWParameters(tls: tlsOptions)
```

- Enforce TLS 1.3 minimum for new connections
- Pin certificates via `sec_protocol_options_set_verify_block`

## SwiftUI Storage Pitfalls

- Never store sensitive data in `@AppStorage` — it writes to `UserDefaults` (plist, unencrypted)
- Never store tokens/passwords in `@SceneStorage` — not encrypted, may sync
- Use Keychain wrapper or `@Environment` injection for sensitive values
