# Runtime Contract

The runtime intentionally stays small.

Provider SDKs should depend on:

- `Prismatic.Client`
- `Prismatic.GovernedAuthority`
- `Prismatic.Operation`
- `Prismatic.Response`
- `Prismatic.Error`

The lower HTTP lane stays an implementation detail. `prismatic` remains the
GraphQL semantic layer above the shared `pristine` HTTP family kit.

They should not treat lower-level helper modules as part of the public
provider-facing contract.

Provider SDKs may keep standalone env, local config, direct bearer, custom
header, and OAuth token-source helpers for direct use. Governed provider paths
must pass `Prismatic.GovernedAuthority` and must not feed env, saved token
files, default clients, or request overrides into `Prismatic.Client`.
