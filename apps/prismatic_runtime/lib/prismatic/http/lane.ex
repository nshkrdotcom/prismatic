defmodule Prismatic.HTTP.Lane do
  @moduledoc false

  alias Pristine.Adapters.Transport.Finch, as: PristineTransport
  alias Pristine.Core.{Context, Request, Response}

  @spec request(
          atom() | String.t(),
          String.t(),
          map() | keyword() | [{String.t(), String.t()}],
          term(),
          keyword()
        ) ::
          {:ok, %{status: integer() | nil, headers: [{String.t(), String.t()}], body: term()}}
          | {:error, term()}
  def request(method, url, headers, body, opts \\ [])
      when is_binary(url) and is_list(opts) do
    request = %Request{
      method: method,
      url: url,
      headers: normalize_headers(headers),
      body: body,
      metadata: request_metadata(opts)
    }

    case PristineTransport.send(request, %Context{}) do
      {:ok, %Response{} = response} ->
        {:ok,
         %{
           status: response.status,
           headers: normalize_response_headers(response.headers),
           body: response.body
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(_headers), do: %{}

  defp normalize_response_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_response_headers(headers) when is_list(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_response_headers(_headers), do: []

  defp request_metadata(opts) do
    case timeout_ms(opts) do
      nil -> %{}
      timeout_ms -> %{timeout: timeout_ms}
    end
  end

  defp timeout_ms(opts) do
    Enum.find_value([:receive_timeout, :timeout_ms, :timeout], fn key ->
      case Keyword.get(opts, key) do
        value when is_integer(value) and value > 0 -> value
        _other -> nil
      end
    end)
  end
end
