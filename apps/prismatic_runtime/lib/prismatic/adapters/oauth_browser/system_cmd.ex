defmodule Prismatic.Adapters.OAuthBrowser.SystemCmd do
  @moduledoc """
  System-command browser launcher adapter for interactive OAuth flows.
  """

  @behaviour Prismatic.Ports.OAuthBrowser

  @impl true
  defdelegate open(url, opts \\ []), to: Prismatic.OAuth2.Browser
end
