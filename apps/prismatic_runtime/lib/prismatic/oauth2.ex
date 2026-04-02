defmodule Prismatic.OAuth2 do
  @moduledoc """
  Generic OAuth2 helpers for GraphQL provider SDKs built on `prismatic`.
  """

  alias Prismatic.OAuth2.{
    AuthorizationRequest,
    Error,
    PKCE,
    Provider,
    Token
  }

  @type result(value) :: {:ok, value} | {:error, Error.t()}

  @spec authorization_request(Provider.t(), keyword()) :: result(AuthorizationRequest.t())
  def authorization_request(%Provider{} = provider, opts \\ []) do
    with {:ok, client_id} <- fetch_required(opts, :client_id, provider, :missing_client_id),
         {:ok, %AuthorizationRequest{} = request, params} <-
           build_authorization_request(provider, opts) do
      {:ok,
       %AuthorizationRequest{
         request
         | url:
             authorization_url_for(provider, client_id, Keyword.get(opts, :redirect_uri), params)
       }}
    end
  end

  @spec authorize_url(Provider.t(), keyword()) :: result(String.t())
  def authorize_url(%Provider{} = provider, opts \\ []) do
    if Keyword.get(opts, :generate_state) || Keyword.get(opts, :pkce) do
      {:error,
       Error.new(:authorization_request_requires_explicit_values, provider: provider.name)}
    else
      with {:ok, request} <- authorization_request(provider, opts) do
        {:ok, request.url}
      end
    end
  end

  @spec exchange_code(Provider.t(), String.t(), keyword()) :: result(Token.t())
  def exchange_code(%Provider{} = provider, code, opts \\ []) when is_binary(code) do
    params =
      []
      |> Keyword.put(:code, code)
      |> maybe_put(:redirect_uri, Keyword.get(opts, :redirect_uri))
      |> maybe_put(:code_verifier, Keyword.get(opts, :pkce_verifier))
      |> Keyword.merge(normalize_keyword(Keyword.get(opts, :token_params, [])))

    token_request(provider, :authorization_code, params, opts)
  end

  @spec refresh_token(Provider.t(), String.t(), keyword()) :: result(Token.t())
  def refresh_token(%Provider{} = provider, refresh_token, opts \\ [])
      when is_binary(refresh_token) do
    params =
      [refresh_token: refresh_token]
      |> Keyword.merge(normalize_keyword(Keyword.get(opts, :token_params, [])))

    token_request(provider, :refresh_token, params, opts)
  end

  @spec client_credentials(Provider.t(), keyword()) :: result(Token.t())
  def client_credentials(%Provider{} = provider, opts \\ []) do
    params = normalize_keyword(Keyword.get(opts, :token_params, []))
    token_request(provider, :client_credentials, params, opts)
  end

  defp build_authorization_request(provider, opts) do
    state = authorization_state(opts)
    pkce = authorization_pkce(opts)
    scopes = authorization_scopes(provider, opts)

    params =
      []
      |> maybe_put(:scope, scopes)
      |> maybe_put(:state, state)
      |> maybe_put(:code_challenge, pkce[:challenge])
      |> maybe_put(:code_challenge_method, pkce_method_param(pkce[:method]))
      |> Keyword.merge(normalize_keyword(Keyword.get(opts, :params, [])))

    {:ok,
     %AuthorizationRequest{
       state: state,
       pkce_verifier: pkce[:verifier],
       pkce_challenge: pkce[:challenge],
       pkce_method: pkce[:method]
     }, params}
  end

  defp token_request(%Provider{} = provider, _grant_type, _params, _opts)
       when is_nil(provider.token_url) do
    {:error, Error.new(:missing_token_url, provider: provider.name)}
  end

  defp token_request(%Provider{} = provider, grant_type, params, opts) do
    with {:ok, client_id} <- fetch_required(opts, :client_id, provider, :missing_client_id),
         {:ok, request_opts} <-
           build_token_request(provider, grant_type, params, client_id, opts),
         {:ok, response} <- execute_request(opts, request_opts, provider),
         {:ok, body, headers} <- normalize_response(response, provider),
         :ok <- ensure_success(response, body, headers, provider) do
      {:ok, Token.from_backend_token(body)}
    end
  end

  defp build_token_request(provider, grant_type, params, client_id, opts) do
    headers = normalize_headers(Keyword.get(opts, :headers, []))

    request_params =
      params
      |> normalize_map()
      |> Map.put_new("grant_type", grant_type_param(grant_type))

    with {:ok, {headers, request_params}} <-
           apply_client_auth_method(
             provider,
             headers,
             request_params,
             client_id,
             Keyword.get(opts, :client_secret)
           ),
         {:ok, body} <-
           encode_request_body(
             provider.token_method,
             provider.token_content_type,
             request_params
           ),
         {:ok, url} <-
           request_url(provider.site, provider.token_url, provider.token_method, request_params) do
      request_opts =
        opts
        |> Keyword.get(:req_options, [])
        |> normalize_req_options()
        |> Keyword.put(:url, url)
        |> Keyword.put(:method, provider.token_method)
        |> Keyword.put(:headers, headers_list(headers, provider))
        |> maybe_put_body(body)

      {:ok, request_opts}
    end
  end

  defp execute_request(opts, request_opts, provider) do
    case http_client(opts).request(request_opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, Error.new(:request_failed, body: reason, provider: provider.name)}
    end
  end

  defp normalize_response(%{status: _status, headers: headers, body: body}, provider) do
    normalized_headers = normalize_headers(headers)

    with {:ok, normalized_body} <- normalize_response_body(body, normalized_headers, provider) do
      {:ok, normalized_body, normalized_headers}
    end
  end

  defp normalize_response(_response, provider) do
    {:error, Error.new(:invalid_http_response, provider: provider.name)}
  end

  defp normalize_response_body(nil, _headers, _provider), do: {:ok, %{}}
  defp normalize_response_body("", _headers, _provider), do: {:ok, %{}}

  defp normalize_response_body(body, _headers, _provider) when is_map(body) do
    {:ok, stringify_keys(body)}
  end

  defp normalize_response_body(body, headers, provider) when is_binary(body) do
    content_type = Map.get(headers, "content-type", "")

    cond do
      String.contains?(content_type, "application/json") ->
        case Jason.decode(body) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, decoded}

          {:ok, _decoded} ->
            {:error, Error.new(:invalid_token_response, body: body, provider: provider.name)}

          {:error, reason} ->
            {:error, Error.new(:invalid_token_response, body: reason, provider: provider.name)}
        end

      String.contains?(content_type, "application/x-www-form-urlencoded") ->
        {:ok, URI.decode_query(body)}

      true ->
        case Jason.decode(body) do
          {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
          _other -> {:ok, URI.decode_query(body)}
        end
    end
  end

  defp ensure_success(%{status: status}, body, headers, provider) do
    cond do
      not is_integer(status) ->
        {:error,
         Error.new(:invalid_http_response, body: body, headers: headers, provider: provider.name)}

      status < 200 or status >= 300 ->
        {:error,
         Error.new(:token_request_failed,
           status: status,
           body: body,
           headers: headers,
           provider: provider.name
         )}

      oauth_error?(body) ->
        {:error,
         Error.new(:token_request_failed,
           status: status,
           body: body,
           headers: headers,
           provider: provider.name,
           message: oauth_error_message(body)
         )}

      true ->
        :ok
    end
  end

  defp oauth_error?(body) when is_map(body) do
    value = Map.get(body, "error") || Map.get(body, :error)
    is_binary(value) and value != ""
  end

  defp oauth_error_message(body) do
    error = Map.get(body, "error") || Map.get(body, :error)
    description = Map.get(body, "error_description") || Map.get(body, :error_description)

    cond do
      is_binary(description) and description != "" ->
        "#{error}: #{description}"

      is_binary(error) and error != "" ->
        error

      true ->
        "token request failed"
    end
  end

  defp authorization_state(opts) do
    cond do
      is_binary(Keyword.get(opts, :state)) -> Keyword.get(opts, :state)
      Keyword.get(opts, :generate_state) -> PKCE.generate(24)
      true -> nil
    end
  end

  defp authorization_pkce(opts) do
    cond do
      is_binary(Keyword.get(opts, :pkce_challenge)) ->
        %{
          verifier: Keyword.get(opts, :pkce_verifier),
          challenge: Keyword.get(opts, :pkce_challenge),
          method: Keyword.get(opts, :pkce_method, :s256)
        }

      is_binary(Keyword.get(opts, :pkce_verifier)) ->
        verifier = Keyword.get(opts, :pkce_verifier)
        method = Keyword.get(opts, :pkce_method, :s256)
        %{verifier: verifier, challenge: PKCE.challenge(verifier, method), method: method}

      Keyword.get(opts, :pkce) ->
        verifier = PKCE.generate(32)
        method = Keyword.get(opts, :pkce_method, :s256)
        %{verifier: verifier, challenge: PKCE.challenge(verifier, method), method: method}

      true ->
        %{verifier: nil, challenge: nil, method: nil}
    end
  end

  defp authorization_scopes(provider, opts) do
    scopes =
      case Keyword.get(opts, :scopes) do
        nil -> provider.default_scopes
        list when is_list(list) -> Enum.map(list, &to_string/1)
        value when is_binary(value) -> [value]
      end

    case scopes do
      [] -> nil
      _ -> Enum.join(scopes, provider.scope_separator)
    end
  end

  defp authorization_url_for(provider, client_id, redirect_uri, params) do
    provider.site
    |> build_url(provider.authorize_url)
    |> append_query(
      params
      |> normalize_map()
      |> Map.put_new("response_type", "code")
      |> Map.put("client_id", client_id)
      |> maybe_put_map("redirect_uri", redirect_uri)
      |> reject_blank_values()
    )
  end

  defp fetch_required(opts, key, provider, error_reason) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, Error.new(error_reason, provider: provider.name)}
    end
  end

  defp request_url(site, path, :get, params) do
    {:ok, append_query(build_url(site, path), reject_blank_values(params))}
  end

  defp request_url(site, path, _method, _params), do: {:ok, build_url(site, path)}

  defp build_url(site, path) when is_binary(path) do
    if String.starts_with?(path, "http://") or String.starts_with?(path, "https://") do
      path
    else
      to_string(site || "") <> path
    end
  end

  defp build_url(site, nil), do: to_string(site || "")
  defp build_url(site, path), do: to_string(site || "") <> to_string(path)

  defp apply_client_auth_method(provider, headers, params, client_id, client_secret) do
    case provider.client_auth_method do
      :basic ->
        apply_basic_client_auth(provider, headers, params, client_id, client_secret)

      :request_body ->
        apply_request_body_client_auth(provider, headers, params, client_id, client_secret)

      :none ->
        {:ok,
         {Map.delete(headers, "authorization"),
          params
          |> Map.delete("client_secret")
          |> Map.put("client_id", client_id)}}
    end
  end

  defp apply_basic_client_auth(provider, headers, params, client_id, client_secret) do
    if present_secret?(client_secret) do
      auth = Base.encode64("#{client_id}:#{client_secret}")

      {:ok,
       {headers
        |> Map.delete("authorization")
        |> Map.put("authorization", "Basic #{auth}"),
        Map.drop(params, ["client_id", "client_secret"])}}
    else
      maybe_use_public_client(provider, headers, params, client_id)
    end
  end

  defp apply_request_body_client_auth(provider, headers, params, client_id, client_secret) do
    if present_secret?(client_secret) do
      {:ok,
       {Map.delete(headers, "authorization"),
        params
        |> Map.put("client_id", client_id)
        |> Map.put("client_secret", client_secret)}}
    else
      maybe_use_public_client(provider, headers, params, client_id)
    end
  end

  defp maybe_use_public_client(%Provider{allow_public_client?: true}, headers, params, client_id) do
    {:ok,
     {Map.delete(headers, "authorization"),
      params
      |> Map.delete("client_secret")
      |> Map.put("client_id", client_id)}}
  end

  defp maybe_use_public_client(%Provider{} = provider, _headers, _params, _client_id) do
    {:error, Error.new(:missing_client_secret, provider: provider.name)}
  end

  defp present_secret?(client_secret) when is_binary(client_secret) and client_secret != "",
    do: true

  defp present_secret?(_client_secret), do: false

  defp encode_request_body(:get, _content_type, _params), do: {:ok, nil}
  defp encode_request_body(_method, nil, _params), do: {:ok, nil}
  defp encode_request_body(_method, _content_type, params) when params == %{}, do: {:ok, nil}

  defp encode_request_body(_method, "application/json", params) do
    case Jason.encode(params) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, Error.new(:request_encoding_failed, body: reason)}
    end
  end

  defp encode_request_body(_method, "application/x-www-form-urlencoded", params) do
    {:ok, URI.encode_query(params)}
  end

  defp encode_request_body(_method, _content_type, params), do: {:ok, params}

  defp headers_list(headers, provider) do
    headers
    |> Map.put_new("accept", "application/json")
    |> maybe_put_header(
      "content-type",
      body_content_type(provider.token_method, provider.token_content_type)
    )
    |> Enum.to_list()
  end

  defp body_content_type(:get, _content_type), do: nil
  defp body_content_type(_method, content_type), do: content_type

  defp http_client(opts) do
    Keyword.get(opts, :http_client, Prismatic.Adapters.OAuthHTTPClient.Req)
  end

  defp grant_type_param(:authorization_code), do: "authorization_code"
  defp grant_type_param(:refresh_token), do: "refresh_token"
  defp grant_type_param(:client_credentials), do: "client_credentials"

  defp pkce_method_param(:plain), do: "plain"
  defp pkce_method_param(:s256), do: "S256"
  defp pkce_method_param(_method), do: nil

  defp append_query(url, params) when params == %{}, do: url
  defp append_query(url, params), do: url <> "?" <> URI.encode_query(params)

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_keyword(value) when is_list(value), do: value
  defp normalize_keyword(value) when is_map(value), do: Enum.into(value, [])
  defp normalize_keyword(_value), do: []

  defp normalize_map(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_map(value) when is_list(value) do
    Map.new(value, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_map(_value), do: %{}

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
  end

  defp normalize_headers(_headers), do: %{}

  defp normalize_req_options(opts) when is_list(opts), do: opts
  defp normalize_req_options(_opts), do: []

  defp reject_blank_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, []), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, _key, ""), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_header(headers, _key, nil), do: headers
  defp maybe_put_header(headers, key, value), do: Map.put_new(headers, key, value)

  defp maybe_put_body(opts, nil), do: Keyword.delete(opts, :body)
  defp maybe_put_body(opts, body), do: Keyword.put(opts, :body, body)
end
