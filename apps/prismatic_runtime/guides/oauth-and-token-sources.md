# OAuth And Token Sources

`Prismatic` owns the generic GraphQL-side OAuth2 substrate. Provider SDKs own
their provider metadata, scope defaults, and user-facing onboarding guidance.

## What Lives In `prismatic`

- generic OAuth2 provider metadata
- authorization URL helpers
- code exchange, refresh, and client-credentials helpers
- interactive browser and loopback callback orchestration
- persisted token file support
- refreshable token-source wrappers
- runtime-side OAuth bearer injection through `oauth2:`

## What Stays In A Provider SDK

- provider-specific authorize and token URLs
- provider-specific scopes and extra auth params
- hosted install UX and callback endpoints
- product wording and environment variable conventions

## Runtime OAuth Client Configuration

Use a token source when a provider SDK wants runtime-managed bearer injection:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    oauth2: [
      token_source:
        {Prismatic.Adapters.TokenSource.File,
         path: "/tmp/provider-oauth.json"}
    ]
  )
```

That token source is resolved at execution time, not just once at client
construction.

## Token File Persistence

The built-in file token source persists the normalized token map as JSON:

```elixir
token = %Prismatic.OAuth2.Token{
  access_token: "access_123",
  refresh_token: "refresh_123",
  expires_at: System.system_time(:second) + 3600
}

:ok =
  Prismatic.Adapters.TokenSource.File.put(
    token,
    path: "/tmp/provider-oauth.json",
    create_dirs?: true
  )
```

## Refreshable Sources

Wrap a persisted source when the provider supports refresh:

```elixir
oauth2_source =
  {Prismatic.Adapters.TokenSource.Refreshable,
   inner_source:
     {Prismatic.Adapters.TokenSource.File,
      path: "/tmp/provider-oauth.json"},
   provider: MyProvider.OAuth.provider(),
   client_id: System.fetch_env!("PROVIDER_CLIENT_ID"),
   client_secret: System.fetch_env!("PROVIDER_CLIENT_SECRET"),
   refresh_skew_seconds: 60}
```

Then pass that wrapped source to `oauth2:`.

## Provider Helper Pattern

Provider repos should expose thin helpers over `Prismatic.OAuth2`, for example:

```elixir
def provider do
  Prismatic.OAuth2.Provider.new(
    name: "linear",
    site: "https://linear.app",
    authorize_url: "/oauth/authorize",
    token_url: "https://api.linear.app/oauth/token",
    default_scopes: ["read"],
    scope_separator: ",",
    client_auth_method: :request_body,
    allow_public_client?: true,
    token_content_type: "application/x-www-form-urlencoded"
  )
end
```

That keeps the runtime generic and the provider repo explicit.

## Interactive Authorization

When a provider SDK wants operator-facing OAuth flows, it can use
`Prismatic.OAuth2.Interactive.authorize/2` with a provider definition and a
registered redirect URI.

For loopback redirects like `http://127.0.0.1:40071/callback`, the interactive
helper can capture the callback directly. For hosted redirects or manual flows,
it falls back to paste-back mode.

Exact loopback capture depends on the optional callback-listener dependencies
being present in the install graph. Without them, the interactive helper still
works, but it falls back to manual paste-back.
