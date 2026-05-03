# Runtime And Execution

`prismatic` executes GraphQL documents over HTTP with a small, explicit
runtime surface.

The runtime owns:

- GraphQL payload construction and execution planning
- auth and header composition
- governed authority materialization
- response normalization
- GraphQL error shaping
- telemetry hooks

The lower HTTP lane is shared instead of repo-local. The default runtime path
now uses a `pristine`-backed transport adapter that delegates unary HTTP
execution through the shared HTTP family kit and its Execution Plane-backed
transport substrate.

Provider repos should call the public runtime surface rather than reach into
internal helper modules.

Standalone provider wrappers may keep direct env, token-file, and OAuth helpers
for local use. Governed wrappers pass `Prismatic.GovernedAuthority`; direct
`base_url:`, `headers:`, `auth:`, `oauth2:`, saved token sources, and
request-time auth or endpoint overrides are rejected at the runtime boundary.
