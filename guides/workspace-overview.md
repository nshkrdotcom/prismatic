# Workspace Overview

`Prismatic` is a non-umbrella monorepo.

The root package is only a tooling workspace. The actual deliverables live in
`apps/`:

- `apps/prismatic_runtime`
- `apps/prismatic_codegen`
- `apps/prismatic_provider_testkit`

This split keeps package ownership explicit while still allowing one shared
workspace for docs, quality tooling, and release automation.
