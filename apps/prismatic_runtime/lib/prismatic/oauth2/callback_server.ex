defmodule Prismatic.OAuth2.CallbackServer do
  @moduledoc """
  Exact loopback callback capture for interactive OAuth flows.
  """

  use GenServer

  alias Prismatic.OAuth2.Error

  @compile {:no_warn_undefined, [Bandit, Plug.Conn]}

  @callback_message :prismatic_oauth2_callback

  defstruct [:pid, :redirect_uri]

  @type t :: %__MODULE__{
          pid: pid(),
          redirect_uri: String.t()
        }

  @type callback_result ::
          {:ok, %{code: String.t(), request_uri: String.t(), state: String.t() | nil}}
          | {:error, Error.t()}

  @type redirect_target :: %{
          redirect_uri: String.t(),
          host: String.t(),
          ip: :inet.ip_address(),
          path: String.t(),
          port: pos_integer(),
          scheme: String.t()
        }

  @readiness_probe_attempts 20
  @readiness_probe_delay_ms 10
  @readiness_probe_timeout_ms 250

  @spec start(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def start(redirect_uri, opts \\ []) when is_binary(redirect_uri) and is_list(opts) do
    with {:ok, redirect} <- parse_loopback_redirect_uri(redirect_uri),
         {:ok, pid} <- start_server(redirect, opts) do
      {:ok, %__MODULE__{pid: pid, redirect_uri: redirect.redirect_uri}}
    end
  end

  @spec await(t(), timeout()) :: callback_result()
  def await(%__MODULE__{pid: pid} = server, timeout_ms) when is_integer(timeout_ms) do
    receive do
      {@callback_message, ^pid, result} ->
        stop(server)
        result
    after
      timeout_ms ->
        stop(server)
        {:error, Error.new(:authorization_callback_timeout)}
    end
  end

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{pid: pid}) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal)
    end

    :ok
  catch
    :exit, _reason -> :ok
  end

  @spec loopback_redirect_uri?(String.t()) :: boolean()
  def loopback_redirect_uri?(redirect_uri) when is_binary(redirect_uri) do
    match?({:ok, _redirect}, parse_loopback_redirect_uri(redirect_uri))
  end

  @doc false
  @spec handle_http_request(pid(), map(), redirect_target()) ::
          {map(), non_neg_integer(), iodata()}
  def handle_http_request(server, conn, redirect) do
    cond do
      conn.method != "GET" ->
        {conn, 405, failure_page("Method not allowed")}

      not request_matches_redirect?(conn, redirect) ->
        {conn, 404, failure_page("Not found")}

      true ->
        conn = Plug.Conn.fetch_query_params(conn)
        callback_uri = callback_uri(redirect, conn.query_string)

        response =
          GenServer.call(server, {:report_callback, conn.params, callback_uri}, :infinity)

        {conn, response.status, response.body}
    end
  end

  @impl GenServer
  def init(%{bandit_module: bandit_module, receiver: receiver, redirect: redirect}) do
    plug_opts = [server: self(), redirect: redirect]

    bandit_opts = [
      plug: {__MODULE__.CallbackPlug, plug_opts},
      ip: redirect.ip,
      port: redirect.port,
      startup_log: false,
      thousand_island_options: [num_acceptors: 1, silent_terminate_on_error: true]
    ]

    case bandit_module.start_link(bandit_opts) do
      {:ok, bandit_pid} ->
        {:ok,
         %{bandit_pid: bandit_pid, delivered?: false, receiver: receiver, redirect: redirect}}

      {:error, reason} ->
        {:stop,
         {:error,
          Error.new(
            :loopback_callback_unavailable,
            message: "failed to start callback server: #{inspect(reason)}"
          )}}
    end
  end

  @impl GenServer
  def handle_call({:report_callback, params, callback_uri}, _from, state) do
    {reply, next_state} =
      if state.delivered? do
        {%{body: failure_page("Authorization callback already handled"), status: 409}, state}
      else
        result = callback_result(params, callback_uri)
        send(state.receiver, {@callback_message, self(), result})
        Process.send_after(self(), :shutdown_listener, 0)
        {response_for_result(result), %{state | delivered?: true}}
      end

    {:reply, reply, next_state}
  end

  @impl GenServer
  def handle_info(:shutdown_listener, %{bandit_pid: bandit_pid} = state) do
    shutdown_bandit(bandit_pid)
    {:noreply, %{state | bandit_pid: nil}}
  end

  @impl GenServer
  def terminate(_reason, %{bandit_pid: bandit_pid}) when is_pid(bandit_pid) do
    shutdown_bandit(bandit_pid)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp start_server(redirect, opts) do
    receiver = Keyword.get(opts, :receiver, self())
    bandit_module = Keyword.get(opts, :bandit_module, Bandit)

    with :ok <- ensure_callback_dependencies_available(opts, bandit_module),
         :ok <- ensure_callback_dependencies_started(bandit_module),
         :ok <- wait_for_bandit_clock(),
         {:ok, pid} <- start_server_process(bandit_module, receiver, redirect),
         {:ok, pid} <- verify_listener_ready(pid, redirect) do
      {:ok, pid}
    else
      {:error, %Error{} = error} ->
        {:error, error}

      {:error, {:error, %Error{} = error}} ->
        {:error, error}

      {:error, reason} ->
        {:error, Error.new(:loopback_callback_unavailable, body: reason)}
    end
  end

  defp ensure_callback_dependencies_available(opts, bandit_module) do
    if Keyword.get_lazy(opts, :dependencies_available?, fn ->
         Code.ensure_loaded?(Plug.Conn) and Code.ensure_loaded?(bandit_module) and
           function_exported?(bandit_module, :start_link, 1)
       end) do
      :ok
    else
      {:error,
       Error.new(
         :loopback_callback_unavailable,
         message:
           "loopback callback capture requires optional :plug and :bandit dependencies to be installed"
       )}
    end
  end

  defp ensure_callback_dependencies_started(_bandit_module) do
    case Application.ensure_all_started(:bandit) do
      {:ok, _started_apps} ->
        :ok

      {:error, reason} ->
        {:error,
         Error.new(
           :loopback_callback_unavailable,
           message: "failed to start callback listener dependencies: #{inspect(reason)}"
         )}
    end
  end

  defp wait_for_bandit_clock do
    wait_for_bandit_clock(@readiness_probe_attempts)
  end

  defp wait_for_bandit_clock(0) do
    {:error,
     Error.new(
       :loopback_callback_unavailable,
       message: "bandit clock did not become ready before the callback listener started"
     )}
  end

  defp wait_for_bandit_clock(attempts_left) do
    case :ets.whereis(Bandit.Clock) do
      table when table != :undefined ->
        case :ets.lookup(table, :date_header) do
          [{:date_header, _value}] ->
            :ok

          _other ->
            Process.sleep(@readiness_probe_delay_ms)
            wait_for_bandit_clock(attempts_left - 1)
        end

      :undefined ->
        Process.sleep(@readiness_probe_delay_ms)
        wait_for_bandit_clock(attempts_left - 1)
    end
  end

  defp start_server_process(bandit_module, receiver, redirect) do
    GenServer.start_link(__MODULE__, %{
      bandit_module: bandit_module,
      receiver: receiver,
      redirect: redirect
    })
  end

  defp verify_listener_ready(pid, redirect) do
    case wait_for_listener_ready(redirect) do
      :ok ->
        {:ok, pid}

      {:error, reason} ->
        shutdown_bandit_process(pid)

        {:error,
         Error.new(
           :loopback_callback_unavailable,
           message: "failed to verify callback server readiness: #{inspect(reason)}"
         )}
    end
  end

  defp wait_for_listener_ready(redirect) do
    probe_request = readiness_probe_request(redirect)
    wait_for_listener_ready(redirect, probe_request, @readiness_probe_attempts)
  end

  defp wait_for_listener_ready(_redirect, _probe_request, 0), do: {:error, :timeout}

  defp wait_for_listener_ready(redirect, probe_request, attempts_left) do
    case probe_listener(redirect, probe_request) do
      :ok ->
        :ok

      {:error, _reason} = error ->
        Process.sleep(@readiness_probe_delay_ms)

        case wait_for_listener_ready(redirect, probe_request, attempts_left - 1) do
          :ok -> :ok
          {:error, _reason} -> error
        end
    end
  end

  defp readiness_probe_request(redirect) do
    probe_path =
      case redirect.path do
        "/__prismatic_ready__" -> "/__prismatic_health__"
        _other -> "/__prismatic_ready__"
      end

    [
      "GET ",
      probe_path,
      " HTTP/1.1\r\nhost: ",
      redirect.host,
      "\r\nconnection: close\r\n\r\n"
    ]
  end

  defp probe_listener(redirect, probe_request) do
    socket_opts = [:binary, active: false, packet: :raw]

    case :gen_tcp.connect(redirect.ip, redirect.port, socket_opts, @readiness_probe_timeout_ms) do
      {:ok, socket} ->
        try do
          with :ok <- :gen_tcp.send(socket, probe_request),
               {:ok, _response} <- :gen_tcp.recv(socket, 0, @readiness_probe_timeout_ms) do
            :ok
          else
            {:error, reason} -> {:error, reason}
          end
        after
          :gen_tcp.close(socket)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_loopback_redirect_uri(redirect_uri) do
    case URI.parse(redirect_uri) do
      %URI{
        scheme: "http",
        host: host,
        port: port,
        path: path,
        query: nil,
        fragment: nil
      }
      when is_binary(host) and is_integer(port) and port > 0 ->
        with {:ok, ip} <- parse_loopback_ip(host) do
          {:ok,
           %{
             redirect_uri:
               normalize_redirect_uri_string("http", host, port, normalize_path(path)),
             scheme: "http",
             host: host,
             ip: ip,
             port: port,
             path: normalize_path(path)
           }}
        end

      %URI{scheme: scheme} when scheme not in [nil, "", "http"] ->
        {:error, Error.new(:unsupported_callback_scheme)}

      _other ->
        {:error, Error.new(:invalid_redirect_uri)}
    end
  end

  defp parse_loopback_ip("localhost") do
    {:error,
     Error.new(
       :loopback_callback_unavailable,
       message:
         "loopback callback capture requires a literal loopback IP host such as 127.0.0.1 or ::1"
     )}
  end

  defp parse_loopback_ip(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, {127, _, _, _} = ip} ->
        {:ok, ip}

      {:ok, {0, 0, 0, 0, 0, 0, 0, 1} = ip} ->
        {:ok, ip}

      {:ok, _ip} ->
        {:error, Error.new(:loopback_callback_unavailable)}

      {:error, _reason} ->
        {:error, Error.new(:invalid_redirect_uri)}
    end
  end

  defp request_matches_redirect?(conn, redirect) do
    conn.port == redirect.port and conn.request_path == redirect.path and
      host_matches?(conn.host, redirect.ip)
  end

  defp host_matches?(host, expected_ip) when is_binary(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ^expected_ip} -> true
      _other -> false
    end
  end

  defp host_matches?(_host, _expected_ip), do: false

  defp callback_result(params, callback_uri) do
    cond do
      present?(params["error"]) ->
        {:error,
         Error.new(
           :authorization_callback_error,
           body: %{
             "error" => params["error"],
             "error_description" => params["error_description"],
             "request_uri" => callback_uri
           },
           message: callback_error_message(params["error"], params["error_description"])
         )}

      present?(params["code"]) ->
        {:ok,
         %{code: params["code"], request_uri: callback_uri, state: blank_to_nil(params["state"])}}

      true ->
        {:error, Error.new(:authorization_code_missing, body: %{"request_uri" => callback_uri})}
    end
  end

  defp response_for_result({:ok, _callback}) do
    %{body: success_page("Authorization received. Return to the terminal."), status: 200}
  end

  defp response_for_result({:error, %Error{} = error}) do
    %{body: failure_page(error.message), status: 400}
  end

  defp callback_error_message(error, nil),
    do: "authorization callback returned error #{inspect(error)}"

  defp callback_error_message(error, description) do
    "authorization callback returned error #{inspect(error)}: #{description}"
  end

  defp callback_uri(redirect, ""), do: redirect.redirect_uri
  defp callback_uri(redirect, query_string), do: redirect.redirect_uri <> "?" <> query_string

  defp normalize_redirect_uri_string(scheme, host, port, path) do
    scheme <> "://" <> host <> ":" <> Integer.to_string(port) <> path
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path(path), do: path

  defp present?(value) when is_binary(value), do: value != ""
  defp present?(_value), do: false

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: value

  defp success_page(message) do
    """
    <html>
      <body>
        <h1>OAuth complete</h1>
        <p>#{message}</p>
      </body>
    </html>
    """
  end

  defp failure_page(message) do
    """
    <html>
      <body>
        <h1>OAuth failed</h1>
        <p>#{message}</p>
      </body>
    </html>
    """
  end

  defp shutdown_bandit_process(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal)
    end

    :ok
  catch
    :exit, _reason -> :ok
  end

  defp shutdown_bandit(bandit_pid) do
    case bandit_pid do
      nil ->
        :ok

      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          Supervisor.stop(pid, :normal)
        end

        :ok
    end
  catch
    :exit, _reason -> :ok
  end

  defmodule CallbackPlug do
    @moduledoc false
    @compile {:no_warn_undefined, [Plug.Conn]}

    alias Prismatic.OAuth2.CallbackServer

    def init(opts), do: opts

    def call(conn, opts) do
      {conn, status, body} =
        CallbackServer.handle_http_request(opts[:server], conn, opts[:redirect])

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(status, body)
    end
  end
end
