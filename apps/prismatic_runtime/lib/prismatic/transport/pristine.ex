defmodule Prismatic.Transport.Pristine do
  @moduledoc false

  @behaviour Prismatic.Transport

  alias Prismatic.HTTP.Lane

  @impl true
  def execute(context, payload, opts) do
    request_opts = Keyword.merge(context.req_options, opts)

    case Lane.request(:post, context.base_url, context.headers, payload, request_opts) do
      {:ok, response} ->
        with {:ok, decoded_body} <- decode_body(response.body) do
          {:ok, %{response | body: decoded_body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(nil), do: {:ok, %{}}
  defp decode_body(""), do: {:ok, %{}}

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, decoded} -> {:error, {:invalid_graphql_response_body, decoded}}
      {:error, reason} -> {:error, {:invalid_graphql_response_body, reason}}
    end
  end

  defp decode_body(body), do: {:error, {:invalid_graphql_response_body, body}}
end
