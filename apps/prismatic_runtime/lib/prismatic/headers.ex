defmodule Prismatic.Headers do
  @moduledoc false

  @spec merge_auth([{String.t(), String.t()}], Prismatic.Context.auth_option()) ::
          [{String.t(), String.t()}]
  def merge_auth(headers, nil), do: headers

  def merge_auth(headers, {:bearer, token}),
    do: put_header(headers, "authorization", "Bearer #{token}")

  def merge_auth(headers, {:header, name, value}),
    do: put_header(headers, String.downcase(name), value)

  @spec put_header([{String.t(), String.t()}], String.t(), String.t()) :: [
          {String.t(), String.t()}
        ]
  def put_header(headers, name, value) do
    lowered = String.downcase(name)

    headers
    |> Enum.reject(fn {key, _value} -> String.downcase(key) == lowered end)
    |> Kernel.++([{lowered, value}])
  end
end
