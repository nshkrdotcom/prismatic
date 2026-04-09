# Runtime And Execution

`prismatic` executes GraphQL documents over HTTP with a small, explicit
runtime surface.

The runtime owns:

- GraphQL payload construction and execution planning
- auth and header composition
- response normalization
- GraphQL error shaping
- telemetry hooks

The lower HTTP lane is shared instead of repo-local. The default runtime path
now uses a `pristine`-backed transport adapter that delegates unary HTTP
execution through the shared HTTP family kit and its Execution Plane-backed
transport substrate.

Provider repos should call the public runtime surface rather than reach into
internal helper modules.
