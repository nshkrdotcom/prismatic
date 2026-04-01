# Runtime And Execution

`prismatic` executes GraphQL documents over HTTP with a small, explicit
runtime surface.

The runtime owns:

- transport
- auth and header composition
- response normalization
- GraphQL error shaping
- telemetry hooks

Provider repos should call the public runtime surface rather than reach into
internal helper modules.
