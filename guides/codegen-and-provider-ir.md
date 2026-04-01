# Codegen And Provider IR

`prismatic_codegen` defines the shared compiler contract for provider repos.

The center of that package is a GraphQL-native provider IR describing:

- provider metadata
- runtime defaults
- operations
- documents
- auth policies
- connection policies
- artifact plans

That IR feeds renderers and verification helpers.
