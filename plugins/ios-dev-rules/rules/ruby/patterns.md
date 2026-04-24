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
# Ruby (iOS Tooling) Patterns

> This file extends [common/patterns.md](../common/patterns.md) with Ruby (iOS tooling) specific content.

## Podspec — Subspec Layering

```ruby
Pod::Spec.new do |s|
  s.name    = 'MyLib'
  s.version = '2.0.0'

  s.subspec 'Core' do |ss|
    ss.source_files = 'Sources/Core/**/*.{h,m}'
  end

  s.subspec 'UI' do |ss|
    ss.source_files = 'Sources/UI/**/*.{h,m}'
    ss.resource_bundles = { 'MyLibUI' => ['Resources/UI/**/*'] }
    ss.dependency 'MyLib/Core'
  end

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.{m,swift}'
    ts.dependency 'OCMock', '~> 3.9'
  end
end
```

## Fastlane — Lane Organization

Use `before_all`, `after_all`, `error` blocks:

```ruby
platform :ios do
  before_all do
    ensure_git_status_clean
    cocoapods(repo_update: true)
  end

  lane :build_staging do
    build_app(scheme: 'MyApp-Staging', export_method: 'ad-hoc')
  end

  after_all do |lane|
    slack(message: "#{lane} succeeded")
  end

  error do |lane, exception|
    slack(message: "#{lane} failed: #{exception.message}")
  end
end
```

## Shared Values Between Lanes

```ruby
lane :build do
  build_app(scheme: 'MyApp')
  lane_context[SharedValues::IPA_OUTPUT_PATH] # auto-set by build_app
end

lane :deploy do
  build
  upload_to_testflight(ipa: lane_context[SharedValues::IPA_OUTPUT_PATH])
end
```

## Custom Fastlane Action

```ruby
module Fastlane
  module Actions
    class BumpPodVersionAction < Action
      def self.run(params)
        podspec = params[:podspec]
        version = params[:version]
        text = File.read(podspec)
        text.gsub!(/s\.version\s*=\s*['"].*['"]/, "s.version = '#{version}'")
        File.write(podspec, text)
        UI.success("Bumped #{podspec} to #{version}")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :podspec, type: String),
          FastlaneCore::ConfigItem.new(key: :version, type: String)
        ]
      end
    end
  end
end
```
