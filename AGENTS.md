# Repository Guidelines

## Project Structure
- Root `mix.exs` coordinates the Prismatic monorepo.
- `apps/prismatic_runtime` is the publishable semantic GraphQL runtime package.
- `apps/prismatic_codegen` and `apps/prismatic_provider_testkit` are tooling/test packages.
- Generated `doc/` output should not be edited.

## Execution Plane Stack
- `prismatic` is the semantic GraphQL family kit. It may carry mapped execution-plane contracts but must not expose raw lower HTTP transport as its product API.
- Keep runtime dependencies publish-aware through `build_support/dependency_resolver.exs`.
- `linear_sdk` is the active proof SDK for this layer.

## Gates
- Prefer root `mix ci` when present.
- Otherwise run the monorepo aliases advertised by the repo: format, compile, test, Credo, Dialyzer, and docs.
- For publishable apps, also verify `mix hex.build --unpack` from the app directory.
