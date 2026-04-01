<p align="center">
  <img src="assets/prismatic.svg" alt="Prismatic" width="200"/>
</p>

<p align="center">
  <a href="https://hex.pm/packages/prismatic"><img src="https://img.shields.io/hexpm/v/prismatic.svg" alt="Hex.pm"/></a>
  <a href="https://hexdocs.pm/prismatic"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="HexDocs"/></a>
  <a href="https://github.com/nshkrdotcom/prismatic"><img src="https://img.shields.io/badge/GitHub-repo-black?logo=github" alt="GitHub"/></a>
</p>

# Prismatic

`Prismatic` is a GraphQL-native Elixir SDK platform built for thin,
configuration-driven provider libraries.

It takes the same broad philosophy as `pristine`, but shifts the center of
gravity from REST request specs to GraphQL documents, operations, connections,
and schema-derived artifacts.

The repo is a non-umbrella monorepo with three packages:

- `prismatic`: shared runtime for GraphQL-over-HTTP execution
- `prismatic_codegen`: shared compiler, Provider IR, and rendering helpers
- `prismatic_provider_testkit`: shared verification helpers for provider repos

The root workspace exists to coordinate those packages with `blitz`.

## Why this exists

GraphQL provider SDKs tend to accumulate the same infrastructure:

- HTTP execution and auth handling
- response and error normalization
- pagination and connection traversal
- schema-driven code generation
- artifact freshness checks
- docs and verification workflows

`Prismatic` pulls that reusable behavior into one place so provider repos can
stay focused on provider configuration, generated artifacts, and a narrow layer
of handwritten convenience helpers.

## Workspace map

- [Workspace Overview](guides/workspace-overview.md): repo layout and package responsibilities
- [Getting Started](guides/getting-started.md): local setup and workspace commands
- [Runtime and Execution](guides/runtime-and-execution.md): the runtime contract and request flow
- [Codegen and Provider IR](guides/codegen-and-provider-ir.md): compiler boundaries and artifact strategy
- [Provider Testkit](guides/provider-testkit.md): freshness and conformance checks
- [Maintaining the Monorepo](guides/maintaining-the-monorepo.md): release and workspace operations

## Quality bar

The workspace is intended to stay clean at all times:

- tests must pass
- compile must be warning-free
- `credo` must stay clean
- `dialyzer` must stay clean
- docs must build from committed guides and package metadata

## Workspace commands

```bash
mix deps.get
mix ci
mix monorepo.test
mix monorepo.credo --strict
mix monorepo.dialyzer
mix monorepo.docs
```

## Package docs

- [apps/prismatic_runtime/README.md](/home/home/p/g/n/prismatic/apps/prismatic_runtime/README.md)
- [apps/prismatic_codegen/README.md](/home/home/p/g/n/prismatic/apps/prismatic_codegen/README.md)
- [apps/prismatic_provider_testkit/README.md](/home/home/p/g/n/prismatic/apps/prismatic_provider_testkit/README.md)
