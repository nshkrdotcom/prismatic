defmodule Prismatic.OAuth2.Error do
  @moduledoc """
  Error returned by the `Prismatic.OAuth2` helpers.
  """

  defexception [:reason, :message, :status, :body, :headers, :provider]

  @type t :: %__MODULE__{
          reason: atom(),
          message: String.t(),
          status: integer() | nil,
          body: term(),
          headers: map(),
          provider: term()
        }

  @spec new(atom(), keyword()) :: t()
  def new(reason, opts \\ []) do
    %__MODULE__{
      reason: reason,
      message: Keyword.get(opts, :message, default_message(reason)),
      status: Keyword.get(opts, :status),
      body: Keyword.get(opts, :body),
      headers: Keyword.get(opts, :headers, %{}),
      provider: Keyword.get(opts, :provider)
    }
  end

  defp default_message(:authorization_request_requires_explicit_values),
    do: "authorize_url/2 requires explicit state or PKCE inputs"

  defp default_message(:invalid_http_response), do: "oauth client returned an invalid response"
  defp default_message(:invalid_token_response), do: "token endpoint returned an invalid payload"
  defp default_message(:missing_client_id), do: "client_id is required"
  defp default_message(:missing_redirect_uri), do: "redirect_uri is required"
  defp default_message(:missing_client_secret), do: "client_secret is required"
  defp default_message(:missing_token_url), do: "provider token_url is required"
  defp default_message(:missing_authorize_url), do: "provider authorize_url is required"
  defp default_message(:request_encoding_failed), do: "failed to encode the token request body"
  defp default_message(:request_failed), do: "oauth http request failed"
  defp default_message(:token_request_failed), do: "token request failed"
  defp default_message(reason), do: "oauth2 error: #{reason}"
end
