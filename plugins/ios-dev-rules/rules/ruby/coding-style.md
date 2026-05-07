---
paths:
  - "**/Gemfile"
  - "**/Podfile"
  - "**/Fastfile"
  - "**/*.rb"
  - "**/*.podspec"
  - "**/*.gemspec"
  - "**/Appfile"
  - "**/Matchfile"
---
# Ruby (iOS Tooling) Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Ruby (iOS tooling) specific content.

## Formatting

- **RuboCop** for auto-formatting and lint — add `rubocop` to Gemfile dev group
- Pin `.ruby-version` in project root (e.g. `3.2.2`)

## Naming

- `snake_case` for methods, variables, file names
- `CamelCase` for classes and modules
- Lane names: descriptive verbs — `build_staging`, `deploy_testflight`, `run_unit_tests`

## Gemfile

Group gems and lock versions:

```ruby
source 'https://rubygems.org'

gem 'cocoapods', '~> 1.15'
gem 'fastlane', '~> 2.220'

group :development do
  gem 'rubocop', require: false
end
```

Always commit `Gemfile.lock`. Run everything via `bundle exec`.

## Podspec

- Semantic versioning: `s.version = '1.2.0'`
- Explicit source, platform, dependency
- Prefer `resource_bundles` over `resources` (avoids namespace collisions)

```ruby
Pod::Spec.new do |s|
  s.name         = 'MyLib'
  s.version      = '1.0.0'
  s.platform     = :ios, '13.0'
  s.source       = { git: 'https://github.com/org/MyLib.git', tag: s.version.to_s }
  s.source_files = 'Sources/**/*.{h,m,swift}'
  s.resource_bundles = { 'MyLib' => ['Resources/**/*.{xib,png,xcassets}'] }
  s.dependency 'Alamofire', '~> 5.9'
end
```

## Fastfile

Group lanes by purpose — test, build, deploy:

```ruby
platform :ios do
  desc 'Run unit tests'
  lane :run_unit_tests do
    scan(scheme: 'MyApp', clean: true)
  end

  desc 'Build and upload to TestFlight'
  lane :deploy_testflight do
    build_app(scheme: 'MyApp')
    upload_to_testflight
  end
end
```

## Comments

写的代码要有详细的注释，注释要求**简洁明了但不臃肿**：重点说清楚 “为什么 / 边界 / 约束 / 坑”，避免重复显而易见的 “是什么”。一句话能讲清楚的不要写两句，命名已经能表达的就不要再加注释。

- Podfile 的 `pod` 按业务/功能分组，组前一行注释说明用途
- Fastfile 的每个 `lane` 必须带 `desc` 描述；lane 内部复杂判断、重试、workaround 要加 `#` 注释说明原因
- Podspec 字段的非默认配置（例如 `resource_bundles`、`user_target_xcconfig`、`pod_target_xcconfig`）要加注释说明为何如此配置
- RuboCop 的 `rubocop:disable` 必须同行注释写清楚绕过原因，不允许裸 disable
- 常量、全局变量、ENV 读取必须注释来源与取值范围，尤其是 CI 相关变量

```ruby
# 业务基础组件
pod 'XXCore', '~> 1.2'
pod 'XXNetwork', '~> 0.8'

# 调试期依赖，打包不参与
group :debug do
  pod 'FLEX', '~> 5.22', configurations: ['Debug']
end

platform :ios do
  desc '出 TestFlight 包并上传'
  lane :deploy_testflight do
    # CI 上禁用交互式 keychain 解锁，避免挂起
    setup_ci if ENV['CI']

    build_app(scheme: 'MyApp')
    upload_to_testflight(skip_waiting_for_build_processing: true) # 不等 ASC 处理，加快流水线
  end
end
```


## Comments

写的代码要有详细的注释，注释要求**简洁明了但不臃肿**：重点说清楚 “为什么 / 边界 / 约束 / 坑”，避免重复显而易见的 “是什么”。一句话能讲清楚的不要写两句，命名已经能表达的就不要再加注释。

Podfile / Fastfile / podspec 中的注释规范：

- 每个 `lane` 前必须有 `desc`，一句话描述用途与产出
- 复杂 `lane` 内关键分支/副作用处加 `#` 注释，说明前置条件、依赖环境变量、失败回滚
- Podfile 中非通用依赖需注明用途（如 `pod 'XXX' # 仅用于 XX 场景`）
- podspec 中 `s.dependency` 若锁定非最新版本，需注明原因

```ruby
platform :ios do
  desc '构建 staging 并上传 TestFlight（需 MATCH_PASSWORD、APP_STORE_CONNECT_API_KEY）'
  lane :deploy_staging do
    # CI 上 keychain 可能未解锁，先解锁避免签名失败
    unlock_keychain(path: ENV['KEYCHAIN_PATH'], password: ENV['KEYCHAIN_PASSWORD'])

    match(type: 'appstore', readonly: true)
    build_app(scheme: 'MyApp-Staging')
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```
