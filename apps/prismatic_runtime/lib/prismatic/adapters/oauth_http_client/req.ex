defmodule Prismatic.Adapters.OAuthHTTPClient.Req do
  @moduledoc false

  @behaviour Prismatic.Ports.OAuthHTTPClient

  alias Prismatic.Adapters.OAuthHTTPClient.Pristine, as: PristineOAuthHTTPClient

  @impl true
  def request(opts), do: PristineOAuthHTTPClient.request(opts)
end
