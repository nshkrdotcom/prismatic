defmodule Prismatic.OAuth2Test do
  use ExUnit.Case, async: true

  import Mox

  alias Prismatic.OAuth2
  alias Prismatic.OAuth2.PKCE
  alias Prismatic.OAuth2.Provider

  setup :set_mox_from_context
  setup :verify_on_exit!

  defp provider(overrides \\ []) do
    Provider.new(
      Keyword.merge(
        [
          name: "linear",
          flow: :authorization_code,
          site: "https://linear.app",
          authorize_url: "/oauth/authorize",
          token_url: "https://api.linear.app/oauth/token",
          default_scopes: ["read"],
          scope_separator: ",",
          client_auth_method: :request_body,
          allow_public_client?: true,
          token_method: :post,
          token_content_type: "application/x-www-form-urlencoded"
        ],
        overrides
      )
    )
  end

  test "builds authorization requests with generated state and PKCE data" do
    assert {:ok, request} =
             OAuth2.authorization_request(provider(),
               client_id: "client-id",
               redirect_uri: "https://example.com/callback",
               scopes: ["read", "write"],
               generate_state: true,
               pkce: true,
               params: [actor: "app"]
             )

    assert is_binary(request.url)
    assert request.url =~ "client_id=client-id"
    assert request.url =~ "redirect_uri=https%3A%2F%2Fexample.com%2Fcallback"
    assert request.url =~ "scope=read%2Cwrite"
    assert request.url =~ "actor=app"
    assert request.url =~ "code_challenge="
    assert request.url =~ "code_challenge_method=S256"
    assert is_binary(request.state)
    assert is_binary(request.pkce_verifier)
    assert is_binary(request.pkce_challenge)
    assert request.pkce_method == :s256
  end

  test "shapes explicit authorize URLs without hidden generated state" do
    verifier = "verifier-123"
    challenge = PKCE.challenge(verifier, :plain)

    assert {:ok, url} =
             OAuth2.authorize_url(provider(),
               client_id: "client-id",
               redirect_uri: "https://example.com/callback",
               state: "state-123",
               pkce_verifier: verifier,
               pkce_method: :plain
             )

    assert url =~ "state=state-123"
    assert url =~ "code_challenge=#{challenge}"
    assert url =~ "code_challenge_method=plain"
  end

  test "exchanges an authorization code through the configured oauth http client" do
    expect(Prismatic.OAuthHTTPClientMock, :request, fn opts ->
      assert opts[:method] == :post
      assert opts[:url] == "https://api.linear.app/oauth/token"

      headers = Map.new(opts[:headers])

      assert headers["accept"] == "application/json"
      assert headers["content-type"] == "application/x-www-form-urlencoded"

      assert URI.decode_query(opts[:body]) == %{
               "client_id" => "client-id",
               "code" => "auth-code",
               "code_verifier" => "verifier-123",
               "grant_type" => "authorization_code",
               "redirect_uri" => "https://example.com/callback"
             }

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: %{
           "access_token" => "secret_123",
           "refresh_token" => "refresh_123",
           "expires_in" => 3600,
           "token_type" => "bearer"
         }
       }}
    end)

    assert {:ok, %Prismatic.OAuth2.Token{} = token} =
             OAuth2.exchange_code(provider(), "auth-code",
               client_id: "client-id",
               redirect_uri: "https://example.com/callback",
               pkce_verifier: "verifier-123",
               http_client: Prismatic.OAuthHTTPClientMock
             )

    assert token.access_token == "secret_123"
    assert token.refresh_token == "refresh_123"
    assert token.token_type == "Bearer"
    assert is_integer(token.expires_at)
  end

  test "refreshes tokens through request-body client auth" do
    expect(Prismatic.OAuthHTTPClientMock, :request, fn opts ->
      assert opts[:method] == :post

      assert URI.decode_query(opts[:body]) == %{
               "client_id" => "client-id",
               "client_secret" => "client-secret",
               "grant_type" => "refresh_token",
               "refresh_token" => "refresh_123"
             }

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: %{
           "access_token" => "secret_456",
           "refresh_token" => "refresh_456",
           "token_type" => "bearer"
         }
       }}
    end)

    assert {:ok, %Prismatic.OAuth2.Token{access_token: "secret_456"}} =
             OAuth2.refresh_token(provider(), "refresh_123",
               client_id: "client-id",
               client_secret: "client-secret",
               http_client: Prismatic.OAuthHTTPClientMock
             )
  end

  test "treats 2xx token responses with OAuth error fields as failures" do
    expect(Prismatic.OAuthHTTPClientMock, :request, fn _opts ->
      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: %{"error" => "invalid_grant", "error_description" => "code expired"}
       }}
    end)

    assert {:error, %Prismatic.OAuth2.Error{reason: :token_request_failed, message: message}} =
             OAuth2.exchange_code(provider(), "auth-code",
               client_id: "client-id",
               http_client: Prismatic.OAuthHTTPClientMock
             )

    assert message == "invalid_grant: code expired"
  end
end
