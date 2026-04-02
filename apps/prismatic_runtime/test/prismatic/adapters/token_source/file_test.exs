defmodule Prismatic.Adapters.TokenSource.FileTest do
  use ExUnit.Case, async: true

  alias Prismatic.Adapters.TokenSource.File
  alias Prismatic.OAuth2.Token

  test "persists and reloads a token" do
    path =
      Path.join(System.tmp_dir!(), "prismatic-token-#{System.unique_integer([:positive])}.json")

    token =
      %Token{
        access_token: "access_123",
        refresh_token: "refresh_123",
        expires_at: System.system_time(:second) + 3600,
        token_type: "Bearer",
        other_params: %{"scope" => "read,write"}
      }

    assert :ok = File.put(token, path: path, create_dirs?: true)
    assert {:ok, %Token{} = loaded} = File.fetch(path: path)
    assert loaded.access_token == token.access_token
    assert loaded.refresh_token == token.refresh_token
    assert loaded.other_params == token.other_params

    Elixir.File.rm(path)
  end
end
