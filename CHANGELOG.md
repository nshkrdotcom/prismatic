# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Added governed GraphQL authority support in `apps/prismatic_runtime`,
  including explicit credential headers, operation policy refs, redaction refs,
  request smuggling rejection, and telemetry redaction tests.

### Changed

- Documented the standalone env/local-token compatibility split from governed
  credential-handle execution.

## [0.2.0] - 2026-04-01

### Added

- Added the interactive OAuth runtime substrate in `apps/prismatic_runtime`,
  including browser launch, loopback callback capture, and manual paste-back
  orchestration.
- Added the callback listener and browser adapter ports plus the Bandit-backed
  and system-command adapter implementations.
- Added runtime coverage for the new interactive OAuth surface, including
  callback-server and interactive-flow tests.

### Changed

- Bumped the workspace and published package versions to `0.2.0`.
- Updated the shared dependency-resolution rules so local workspace work still
  prefers sibling packages while release-locking commands stay publishable.
- Clarified the runtime OAuth guide around optional loopback capture and the
  manual fallback path.

## [0.1.0] - 2026-04-01

Initial release.

[0.2.0]: https://github.com/nshkrdotcom/prismatic/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nshkrdotcom/prismatic/releases/tag/v0.1.0
