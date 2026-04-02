defmodule Prismatic.Ports.OAuthHTTPClient do
  @moduledoc """
  Boundary for OAuth control-plane HTTP requests.
  """

  @callback request(keyword()) :: {:ok, map()} | {:error, term()}
end
