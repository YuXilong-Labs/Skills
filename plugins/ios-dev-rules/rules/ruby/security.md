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
# Ruby (iOS Tooling) Security

> This file extends [common/security.md](../common/security.md) with Ruby (iOS tooling) specific content.

## Never Hardcode Secrets in Fastfile

No Apple IDs, passwords, API keys, or tokens in source:

```ruby
# WRONG
app_store_connect_api_key(
  key_id: "ABC123",
  issuer_id: "xxx-yyy",
  key_content: "-----BEGIN PRIVATE KEY-----\nMIGT..."
)

# CORRECT
app_store_connect_api_key(
  key_id: ENV.fetch('ASC_KEY_ID'),
  issuer_id: ENV.fetch('ASC_ISSUER_ID'),
  key_filepath: ENV.fetch('ASC_KEY_PATH')
)
```

## Certificate & Profile Management

- Use **match** for code signing — never manual cert/profile management
- Store match repo as private, encrypted Git repo or S3 bucket
- Rotate match passphrase periodically

## Environment Variables

- Use `ENV.fetch('KEY')` (raises on missing) over `ENV['KEY']` for required values
- Document required env vars in `.env.example` (never commit `.env`)
- Use `dotenv` gem for local development only

## Gemfile.lock

- Always commit `Gemfile.lock` to Git — ensures reproducible builds across CI and team
- Run `bundle update` deliberately, not accidentally

## Custom Fastlane Actions

Validate all external inputs:

```ruby
def self.run(params)
  version = params[:version]
  raise 'Invalid version format' unless version.match?(/\A\d+\.\d+\.\d+\z/)
end
```
