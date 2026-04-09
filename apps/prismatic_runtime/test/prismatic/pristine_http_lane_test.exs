defmodule Prismatic.PristineHTTPLaneTest do
  use ExUnit.Case, async: false

  @socket_skip (case :gen_tcp.listen(0, [
                       :binary,
                       active: false,
                       ip: {127, 0, 0, 1},
                       reuseaddr: true
                     ]) do
                  {:ok, socket} ->
                    :gen_tcp.close(socket)
                    nil

                  {:error, reason} ->
                    "loopback sockets unavailable in this environment: #{inspect(reason)}"
                end)
  @moduletag skip: @socket_skip

  alias Prismatic.Context
  alias Prismatic.OAuth2.Provider

  setup do
    {:ok, %{server: server_pid, port: port}} = start_server(self())

    on_exit(fn ->
      stop_server(server_pid)
    end)

    {:ok, port: port}
  end

  test "context defaults to the pristine-backed GraphQL transport lane" do
    assert %Context{transport: Prismatic.Transport.Pristine} =
             Context.new!(base_url: "https://api.example.com/graphql")
  end

  test "the pristine-backed transport executes GraphQL requests over the shared HTTP lane", %{
    port: port
  } do
    context =
      Context.new!(
        base_url: "http://localhost:#{port}/graphql",
        headers: [{"authorization", "Bearer secret"}]
      )

    payload = %{"query" => "query Viewer { viewer { id } }", "variables" => %{}}

    assert {:ok,
            %{
              status: 200,
              headers: headers,
              body: %{"data" => %{"viewer" => %{"id" => "user_1"}}}
            }} = Prismatic.Transport.Pristine.execute(context, payload, receive_timeout: 500)

    assert is_list(headers)

    assert_receive {:prismatic_http_request, request}, 1_000
    assert request.path == "/graphql"
    assert request.method == "POST"
    assert request.headers["authorization"] == "Bearer secret"
    assert Jason.decode!(request.body) == payload
  end

  test "the pristine-backed OAuth HTTP client executes token requests over the shared HTTP lane",
       %{port: port} do
    assert {:ok,
            %{
              status: 200,
              headers: headers,
              body: body
            }} =
             Prismatic.Adapters.OAuthHTTPClient.Pristine.request(
               method: :post,
               url: "http://localhost:#{port}/oauth/token",
               headers: [{"content-type", "application/x-www-form-urlencoded"}],
               body:
                 URI.encode_query(%{
                   "grant_type" => "authorization_code",
                   "code" => "auth-code"
                 }),
               receive_timeout: 500
             )

    assert is_list(headers)

    assert body == %{
             "access_token" => "secret_123",
             "refresh_token" => "refresh_123",
             "token_type" => "bearer"
           }

    assert_receive {:prismatic_http_request, request}, 1_000
    assert request.path == "/oauth/token"
    assert request.method == "POST"
    assert request.headers["content-type"] =~ "application/x-www-form-urlencoded"

    assert URI.decode_query(request.body) == %{
             "grant_type" => "authorization_code",
             "code" => "auth-code"
           }
  end

  test "oauth2 defaults to the pristine-backed HTTP client when no override is provided", %{
    port: port
  } do
    provider =
      Provider.new(
        name: "linear",
        flow: :authorization_code,
        site: "https://linear.app",
        authorize_url: "/oauth/authorize",
        token_url: "http://localhost:#{port}/oauth/token",
        default_scopes: ["read"],
        scope_separator: ",",
        client_auth_method: :request_body,
        allow_public_client?: true,
        token_method: :post,
        token_content_type: "application/x-www-form-urlencoded"
      )

    assert {:ok, %Prismatic.OAuth2.Token{access_token: "secret_123"}} =
             Prismatic.OAuth2.exchange_code(provider, "auth-code",
               client_id: "client-id",
               receive_timeout: 500
             )

    assert_receive {:prismatic_http_request, request}, 1_000
    assert request.path == "/oauth/token"
    assert URI.decode_query(request.body)["client_id"] == "client-id"
  end

  defp stop_supervised_pid(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      try do
        Process.exit(pid, :normal)
      catch
        :exit, _ -> :ok
      end
    end
  end

  defp start_server(test_pid) when is_pid(test_pid) do
    with {:ok, listen_socket} <-
           :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true]),
         {:ok, port} <- inet_port(listen_socket) do
      server_pid =
        spawn_link(fn ->
          accept_loop(listen_socket, test_pid)
        end)

      {:ok, %{server: server_pid, port: port, socket: listen_socket}}
    end
  end

  defp inet_port(listen_socket) do
    case :inet.sockname(listen_socket) do
      {:ok, {_ip, port}} -> {:ok, port}
      {:error, reason} -> {:error, reason}
    end
  end

  defp accept_loop(listen_socket, test_pid) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        serve_request(socket, test_pid)
        accept_loop(listen_socket, test_pid)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  defp serve_request(socket, test_pid) do
    with {:ok, request} <- read_http_request(socket),
         :ok <- send_http_response(socket, request, test_pid) do
      :ok
    else
      _other -> :ok
    end

    :gen_tcp.close(socket)
  end

  defp read_http_request(socket, buffer \\ "") do
    case :binary.match(buffer, "\r\n\r\n") do
      {headers_end, 4} ->
        header_block = binary_part(buffer, 0, headers_end)
        body_start = headers_end + 4
        body = binary_part(buffer, body_start, byte_size(buffer) - body_start)
        request = parse_http_request(header_block, body)
        content_length = content_length(request)

        if complete_body?(body, content_length) do
          {:ok, %{request | body: binary_part(body, 0, content_length)}}
        else
          read_http_request_chunk(socket, buffer)
        end

      :nomatch ->
        read_http_request_chunk(socket, buffer)
    end
  end

  defp parse_http_request(header_block, body) do
    [request_line | header_lines] = String.split(header_block, "\r\n", trim: true)
    [method, path, _version] = String.split(request_line, " ", parts: 3)

    headers =
      Map.new(header_lines, fn line ->
        [key, value] = String.split(line, ":", parts: 2)
        {String.downcase(key), String.trim_leading(value)}
      end)

    %{
      method: method,
      path: path,
      headers: headers,
      body: body
    }
  end

  defp send_http_response(socket, request, test_pid) do
    send(test_pid, {:prismatic_http_request, request})

    {status, headers, body} =
      case {request.path, request.method} do
        {"/graphql", "POST"} ->
          {200, [{"content-type", "application/json"}],
           Jason.encode!(%{"data" => %{"viewer" => %{"id" => "user_1"}}})}

        {"/oauth/token", "POST"} ->
          {200, [{"content-type", "application/json"}],
           Jason.encode!(%{
             "access_token" => "secret_123",
             "refresh_token" => "refresh_123",
             "token_type" => "bearer"
           })}

        _other ->
          {404, [{"content-type", "text/plain"}], "not found"}
      end

    response = [
      "HTTP/1.1 ",
      Integer.to_string(status),
      " ",
      status_reason(status),
      "\r\n",
      Enum.map(headers, fn {key, value} -> [key, ": ", value, "\r\n"] end),
      "content-length: ",
      Integer.to_string(byte_size(body)),
      "\r\n",
      "\r\n",
      body
    ]

    case :gen_tcp.send(socket, response) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp status_reason(200), do: "OK"
  defp status_reason(404), do: "Not Found"
  defp status_reason(_status), do: "OK"

  defp content_length(request) do
    request.headers
    |> Map.get("content-length", "0")
    |> String.to_integer()
  end

  defp complete_body?(body, content_length), do: byte_size(body) >= content_length

  defp read_http_request_chunk(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, chunk} -> read_http_request(socket, buffer <> chunk)
      {:error, reason} -> {:error, reason}
    end
  end

  defp stop_server(pid) when is_pid(pid) do
    stop_supervised_pid(pid)
  end
end
