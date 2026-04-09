defmodule Prismatic.Adapters.OAuthHTTPClient.Pristine do
  @moduledoc false

  @behaviour Prismatic.Ports.OAuthHTTPClient

  alias Prismatic.HTTP.Lane

  @impl true
  def request(opts) do
    method = Keyword.get(opts, :method, :get)
    url = Keyword.fetch!(opts, :url)
    headers = Keyword.get(opts, :headers, [])
    body = Keyword.get(opts, :body)

    case Lane.request(method, url, headers, body, opts) do
      {:ok, response} ->
        {:ok, %{response | body: normalize_body(response.body, response.headers)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_body(body, _headers) when is_map(body), do: body
  defp normalize_body(body, _headers) when body in [nil, ""], do: %{}

  defp normalize_body(body, headers) when is_binary(body) do
    if json_content_type?(headers) do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _reason} -> body
      end
    else
      body
    end
  end

  defp normalize_body(body, _headers), do: body

  defp json_content_type?(headers) do
    Enum.any?(headers, fn
      {key, value} ->
        String.downcase(to_string(key)) == "content-type" and
          String.contains?(String.downcase(to_string(value)), "application/json")

      _other ->
        false
    end)
  end
end
