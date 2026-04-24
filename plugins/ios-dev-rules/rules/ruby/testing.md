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
# Ruby (iOS Tooling) Testing

> This file extends [common/testing.md](../common/testing.md) with Ruby (iOS tooling) specific content.

## Podspec Validation

```bash
# Quick syntax check
bundle exec pod lib lint MyLib.podspec --quick

# Full validation (builds + tests)
bundle exec pod lib lint MyLib.podspec --allow-warnings

# Validate against private spec repo
bundle exec pod spec lint MyLib.podspec --sources='https://github.com/org/Specs.git,trunk'
```

## Fastlane — Running Tests

Use `scan` action (wraps `xcodebuild test`):

```ruby
lane :test do
  scan(
    scheme: 'MyApp',
    devices: ['iPhone 16'],
    code_coverage: true,
    output_types: 'junit',
    clean: true
  )
end
```

## Fastlane Plugin Testing

Use **RSpec** for custom action tests:

```ruby
# spec/bump_pod_version_action_spec.rb
require 'fastlane'

RSpec.describe Fastlane::Actions::BumpPodVersionAction do
  it 'bumps version in podspec' do
    podspec = Tempfile.new(['Test', '.podspec'])
    podspec.write("s.version = '1.0.0'")
    podspec.close

    described_class.run(podspec: podspec.path, version: '2.0.0')
    expect(File.read(podspec.path)).to include("s.version = '2.0.0'")
  end
end
```

## Coverage

Add **SimpleCov** to `spec/spec_helper.rb`:

```ruby
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 80
end
```
