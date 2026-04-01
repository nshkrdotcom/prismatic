# Prismatic Task Ledger

## Goal

Create `prismatic` as the GraphQL-native sibling to `pristine`:

- non-umbrella monorepo
- shared runtime package
- shared codegen package
- shared provider testkit
- workspace orchestration with `blitz`
- professional docs, branding, release metadata, and quality gates

## Required Reading

- [README.md](/home/home/p/g/n/prismatic/README.md)
- [guides/workspace-overview.md](/home/home/p/g/n/prismatic/guides/workspace-overview.md)
- [guides/runtime-and-execution.md](/home/home/p/g/n/prismatic/guides/runtime-and-execution.md)
- [guides/codegen-and-provider-ir.md](/home/home/p/g/n/prismatic/guides/codegen-and-provider-ir.md)
- [guides/provider-testkit.md](/home/home/p/g/n/prismatic/guides/provider-testkit.md)
- [guides/maintaining-the-monorepo.md](/home/home/p/g/n/prismatic/guides/maintaining-the-monorepo.md)

## Work Items

- [x] Create GitHub repo and local clone
- [x] Generate clean Elixir skeletons for workspace packages
- [x] Establish root workspace docs, license, changelog, and task ledger
- [x] Replace generated boilerplate with `blitz` workspace wiring
- [x] Implement `prismatic` runtime through TDD/RGR
- [x] Implement `prismatic_codegen` through TDD/RGR
- [x] Implement `prismatic_provider_testkit` through TDD/RGR
- [x] Add SVG branding and wire HexDocs logo/assets
- [x] Finalize root README and guides
- [x] Run `mix format`
- [x] Run workspace tests
- [x] Run workspace Credo
- [x] Run workspace Dialyzer
- [x] Run workspace docs
- [x] Run full workspace `mix ci`
- [ ] Commit and push

## Progress Log

- 2026-04-01: Created remote repo, cloned locally, generated base project skeletons, and started replacing the boilerplate with the monorepo layout.
- 2026-04-01: Completed the `blitz` workspace wiring with shared runtime, codegen, and provider-testkit packages.
- 2026-04-01: Kept the repo fully provider-neutral while building the generator-first core and generic fixtures.
- 2026-04-01: Fixed workspace test orchestration for shared build paths and removed the stale `uuid` dependency from the runtime package.
- 2026-04-01: Implemented formatted Elixir artifact generation, artifact verification, and mix task support for `prismatic.codegen.ir`, `prismatic.codegen.generate`, and `prismatic.codegen.verify`.
- 2026-04-01: Added generated markdown reference-doc rendering, managed generated-doc cleanup, and verification coverage for obsolete generated files.
- 2026-04-01: Expanded the publishable `prismatic` package docs with generic client-configuration guidance and a dedicated `Developer Guides` section.
- 2026-04-01: Verified `mix ci` passes cleanly across format, compile, tests, Credo, Dialyzer, and docs.
