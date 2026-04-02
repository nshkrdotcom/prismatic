defmodule Prismatic.Adapters.TokenSource.RefreshableTest do
  use ExUnit.Case, async: true

  alias Prismatic.Adapters.TokenSource.Refreshable
  alias Prismatic.Adapters.TokenSource.Static
  alias Prismatic.OAuth2.Provider
  alias Prismatic.OAuth2.Token

  defmodule OAuth2Mock do
    alias Prismatic.OAuth2.Token

    def refresh_token(provider, refresh_token, opts) do
      send(self(), {:oauth_refresh, provider, refresh_token, opts})

      {:ok,
       %Token{
         access_token: "access_new",
         refresh_token: "refresh_new",
         expires_at: System.system_time(:second) + 7200,
         token_type: "Bearer"
       }}
    end
  end

  test "refreshes expiring tokens and persists the rotated value" do
    source =
      {Static,
       token: %Token{
         access_token: "access_old",
         refresh_token: "refresh_old",
         expires_at: System.system_time(:second) - 10,
         token_type: "Bearer"
       }}

    provider =
      Provider.new(
        name: "linear",
        token_url: "https://api.linear.app/oauth/token",
        client_auth_method: :request_body,
        allow_public_client?: true
      )

    assert {:ok, %Token{} = token} =
             Refreshable.fetch(
               inner_source: source,
               provider: provider,
               client_id: "client-id",
               oauth2_module: OAuth2Mock
             )

    assert_received {:oauth_refresh, %Provider{name: "linear"}, "refresh_old", refresh_opts}
    assert refresh_opts[:client_id] == "client-id"
    assert token.access_token == "access_new"
    assert token.refresh_token == "refresh_new"
  end
end
