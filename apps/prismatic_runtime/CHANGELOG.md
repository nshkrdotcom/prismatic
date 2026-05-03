# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Added `Prismatic.GovernedAuthority` for authority-selected GraphQL endpoints,
  credential headers, target refs, operation policy refs, and redaction refs.
- Added governed runtime tests covering auth rejection, request-option
  smuggling rejection, telemetry redaction, and application-config isolation.

### Changed

- Governed clients now reject direct endpoint, header, bearer, OAuth, token
  source, and request override inputs while preserving standalone direct auth
  and OAuth behavior.

## [0.2.0] - 2026-04-01

### Added

- Added the interactive OAuth authorization-code orchestration surface through
  `Prismatic.OAuth2.Interactive`.
- Added the exact loopback callback listener through
  `Prismatic.OAuth2.CallbackServer`.
- Added browser-launch and callback-listener ports plus the default system and
  Bandit-backed adapters.
- Added callback-server and interactive-flow tests covering manual fallback,
  callback errors, and exact redirect matching.

### Changed

- Bumped the published `prismatic` runtime version to `0.2.0`.
- Tightened callback-listener startup so dependency readiness and listener
  readiness are verified before the interactive flow proceeds.
- Clarified the runtime OAuth guide around optional loopback capture and manual
  paste-back fallback.

## [0.1.0] - 2026-04-01

### Initial Release

[0.2.0]: https://github.com/nshkrdotcom/prismatic/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nshkrdotcom/prismatic/releases/tag/v0.1.0
