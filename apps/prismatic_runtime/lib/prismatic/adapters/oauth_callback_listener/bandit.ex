defmodule Prismatic.Adapters.OAuthCallbackListener.Bandit do
  @moduledoc """
  Bandit-backed loopback callback listener adapter for interactive OAuth flows.
  """

  @behaviour Prismatic.Ports.OAuthCallbackListener

  @impl true
  defdelegate start(redirect_uri, opts \\ []), to: Prismatic.OAuth2.CallbackServer

  @impl true
  defdelegate await(server, timeout_ms), to: Prismatic.OAuth2.CallbackServer

  @impl true
  defdelegate stop(server), to: Prismatic.OAuth2.CallbackServer

  @impl true
  defdelegate loopback_redirect_uri?(redirect_uri), to: Prismatic.OAuth2.CallbackServer
end
