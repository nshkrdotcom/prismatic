defmodule Prismatic.OAuth2.Provider do
  @moduledoc """
  Normalized OAuth2 provider configuration for GraphQL SDKs.
  """

  defstruct name: nil,
            flow: :authorization_code,
            site: nil,
            authorize_url: nil,
            token_url: nil,
            revocation_url: nil,
            introspection_url: nil,
            scopes: %{},
            default_scopes: [],
            scope_separator: " ",
            client_auth_method: :basic,
            allow_public_client?: false,
            token_method: :post,
            token_content_type: "application/x-www-form-urlencoded",
            metadata: %{}

  @type t :: %__MODULE__{
          name: String.t() | nil,
          flow: :authorization_code | :client_credentials | :refresh_token,
          site: String.t() | nil,
          authorize_url: String.t() | nil,
          token_url: String.t() | nil,
          revocation_url: String.t() | nil,
          introspection_url: String.t() | nil,
          scopes: map(),
          default_scopes: [String.t()],
          scope_separator: String.t(),
          client_auth_method: :basic | :request_body | :none,
          allow_public_client?: boolean(),
          token_method: :get | :post,
          token_content_type: String.t() | nil,
          metadata: map()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end
