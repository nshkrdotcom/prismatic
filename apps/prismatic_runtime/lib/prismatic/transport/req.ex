defmodule Prismatic.Transport.Req do
  @moduledoc false

  @behaviour Prismatic.Transport

  @impl true
  def execute(context, payload, opts) do
    request_options =
      context.req_options
      |> Keyword.merge(opts)
      |> Keyword.put(:url, context.base_url)
      |> Keyword.put(:method, :post)
      |> Keyword.put(:headers, context.headers)
      |> Keyword.put(:json, payload)

    case Req.request(request_options) do
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
