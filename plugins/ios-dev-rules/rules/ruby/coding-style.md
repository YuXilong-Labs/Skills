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
