defmodule Prismatic.ClientOAuth2Test do
  use ExUnit.Case, async: true

  import Mox

  alias Prismatic.Client
  alias Prismatic.OAuth2.Token
  alias Prismatic.Response

  setup :verify_on_exit!

  test "resolves oauth2 token sources at execution time" do
    expect(Prismatic.TransportMock, :execute, fn context, payload, _opts ->
      assert {"authorization", "Bearer oauth-token"} in context.headers
      assert payload["operationName"] == "Viewer"

      {:ok,
       %{
         status: 200,
         headers: [],
         body: %{"data" => %{"viewer" => %{"id" => "user_1"}}}
       }}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        oauth2: [
          token_source:
            {Prismatic.Adapters.TokenSource.Static,
             token: %Token{access_token: "oauth-token", token_type: "Bearer"}}
        ],
        transport: Prismatic.TransportMock
      )

    assert {:ok, %Response{data: %{"viewer" => %{"id" => "user_1"}}}} =
             Client.execute_document(client, "query Viewer { viewer { id } }")
  end

  test "returns a normalized auth error when oauth2 token resolution fails" do
    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        oauth2: [token_source: Prismatic.Adapters.TokenSource.Static],
        transport: Prismatic.TransportMock
      )

    assert {:error, %Prismatic.Error{type: :auth, details: %{reason: :missing_oauth2_token}}} =
             Client.execute_document(client, "query Viewer { viewer { id } }")
  end
end
