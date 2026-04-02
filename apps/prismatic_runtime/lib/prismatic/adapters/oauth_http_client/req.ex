defmodule Prismatic.Adapters.OAuthHTTPClient.Req do
  @moduledoc false

  @behaviour Prismatic.Ports.OAuthHTTPClient

  @impl true
  def request(opts) do
    case Req.request(opts) do
      {:ok, response} ->
        {:ok,
         %{
           status: response.status,
           headers: response.headers,
           body: response.body
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
