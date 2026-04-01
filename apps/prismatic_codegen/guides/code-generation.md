# Code Generation

`prismatic_codegen` translates provider definitions into a normalized Provider
IR that renderers and verification tooling can consume.

The goal is to keep provider repos thin and push generic compilation behavior
into the shared platform.

Generated outputs are not limited to Elixir modules.

The codegen layer also owns the generated reference-doc tree for provider SDKs,
so a provider repo can commit:

- generated operations
- generated models
- generated enums
- generated markdown reference pages

This keeps provider documentation structurally complete while still allowing
handwritten getting-started and workflow guides to stay provider-specific.
