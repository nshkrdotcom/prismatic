# Repository Guidelines

## Project Structure
- Root `mix.exs` coordinates the Prismatic monorepo.
- `apps/prismatic_runtime` is the publishable semantic GraphQL runtime package.
- `apps/prismatic_codegen` and `apps/prismatic_provider_testkit` are tooling/test packages.
- Generated `doc/` output should not be edited.

## Execution Plane Stack
- `prismatic` is the semantic GraphQL family kit. It may carry mapped execution-plane contracts but must not expose raw lower HTTP transport as its product API.
- Keep runtime dependencies publish-aware through
  `build_support/dependency_sources.config.exs` and the canonical
  `build_support/dependency_sources.exs` helper.
- Local dependency-source overrides belong in `.dependency_sources.local.exs`
  or app-local `.dependency_sources.local.exs` files. Keep those files
  untracked.
- Dependency source selection must not use environment variables.
- In local sibling mode, `:execution_plane` resolves to
  `../execution_plane/core/execution_plane`. Do not point `:execution_plane` at
  the sibling repo root; that root is the non-published Blitz workspace
  project.
- `linear_sdk` is the active proof SDK for this layer.
- Runtime application code under `lib/**` must not call direct OS env APIs such
  as `System.get_env/1`, `System.fetch_env/1`, `System.fetch_env!/1`,
  `System.put_env/2`, `System.delete_env/1`, or `System.get_env/0`.
- Runtime env reads belong in `config/runtime.exs` or a `Config.Provider`;
  library APIs should receive explicit options or materialized application
  config.
- Prismatic is not in the Weld consumer set. Do not add a Weld dependency, Weld
  task, or Weld Credo check as part of Phase 2 cleanup.

## Gates
- Prefer root `mix ci` when present.
- Otherwise run the monorepo aliases advertised by the repo: format, compile, test, Credo, Dialyzer, and docs.
- For publishable apps, also verify `mix hex.build --unpack` from the app directory.

## Blitz 0.3.0 operational note

Root workspace Blitz uses published Hex `~> 0.3.0` by default; `.blitz/` is committed compact impact state after green QC. Source and `mix.exs` changes cascade through reverse workspace dependencies; docs-only changes should stay owner-local.
