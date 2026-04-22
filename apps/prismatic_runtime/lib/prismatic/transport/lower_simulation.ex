defmodule Prismatic.Transport.LowerSimulation do
  @moduledoc """
  Configured GraphQL simulation transport over Pristine lower HTTP simulation.

  This adapter is selected through normal Prismatic client transport
  configuration. It resolves GraphQL operation profiles, converts them into
  Pristine lower-simulation transport profiles, and lets the existing
  Prismatic response normalization handle GraphQL data and errors.
  """

  @behaviour Prismatic.Transport

  alias Prismatic.{AdapterSelectionPolicy, LowerSimulationScenario}
  alias Pristine.Adapters.Transport.LowerSimulation, as: PristineLowerSimulation
  alias Pristine.Core.{Context, Request, Response}

  @app :prismatic
  @config_key :graphql_simulation_profiles
  @default_side_effect_policy "deny_external_egress"
  @missing {__MODULE__, :missing}

  @doc """
  Declares the Phase 6 adapter selection policy for Prismatic GraphQL simulation.
  """
  @spec adapter_selection_policy() :: AdapterSelectionPolicy.t()
  def adapter_selection_policy do
    AdapterSelectionPolicy.new!(%{
      selection_surface: "application_config",
      owner_repo: "prismatic",
      config_key: "prismatic.graphql_simulation_profiles",
      default_value_when_unset: "normal_graphql_transport",
      fail_closed_action_when_misconfigured: "reject_required_or_invalid_profile"
    })
  end

  @doc """
  Builds the owner-local Phase 6 lower scenario declaration for a GraphQL profile.
  """
  @spec lower_simulation_scenario!(String.t(), map() | keyword()) ::
          LowerSimulationScenario.t()
  def lower_simulation_scenario!(scenario_ref, overrides \\ []) when is_binary(scenario_ref) do
    overrides = normalize_overrides!(overrides)

    %{
      scenario_id: scenario_ref,
      version: "1.0.0",
      owner_repo: "prismatic",
      route_kind: "graphql_operation",
      protocol_surface: "graphql",
      matcher_class: "deterministic_over_input",
      status_or_exit_or_response_or_stream_or_chunk_or_fault_shape: %{
        "status_code" => "configured",
        "headers" => "configured",
        "data" => "configured",
        "errors" => "configured",
        "extensions" => "configured"
      },
      no_egress_assertion: %{
        "external_egress" => "deny",
        "process_spawn" => "deny",
        "side_effect_result" => "not_attempted"
      },
      bounded_evidence_projection: %{
        "contract_version" => "ExecutionPlane.LowerSimulationEvidence.v1",
        "raw_payload_persistence" => "shape_only",
        "fingerprints" => ["operation", "variables_shape", "response_shape"]
      },
      input_fingerprint_ref: "fingerprint://prismatic/graphql/lower-simulation/input",
      cleanup_behavior: %{
        "runtime_artifacts" => "delete",
        "durable_payload" => "deny_raw"
      }
    }
    |> Map.merge(overrides)
    |> LowerSimulationScenario.new!()
  end

  @impl true
  def execute(%Prismatic.Context{} = context, payload, opts) when is_map(payload) do
    request_opts = Keyword.merge(context.req_options, opts)

    with :ok <- reject_public_simulation_selector(context.req_options),
         :ok <- reject_public_simulation_selector(opts),
         {:ok, endpoint_id, pristine_config} <- pristine_profile_config(context, payload),
         {:ok, %Response{} = response} <-
           payload
           |> build_request(context, endpoint_id, request_opts)
           |> PristineLowerSimulation.send(%Context{transport_opts: pristine_config}),
         {:ok, decoded_body} <- decode_body(response.body) do
      {:ok,
       %{
         status: response.status,
         headers: normalize_response_headers(response.headers),
         body: decoded_body,
         metadata: response.metadata
       }}
    end
  end

  defp pristine_profile_config(%Prismatic.Context{} = context, payload) do
    config = merged_config(context)
    keys = profile_keys(payload)

    with :ok <- reject_public_simulation_selector(config),
         {:ok, _required?} <- required?(config),
         {:ok, profile} <- configured_profile(config, keys),
         {:ok, pristine_profile} <- normalize_profile(profile) do
      endpoint_id = List.first(keys)
      {:ok, endpoint_id, [required?: true, profiles: %{endpoint_id => pristine_profile}]}
    else
      {:missing, keys} -> {:error, {:prismatic_simulation_profile_required, keys}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp merged_config(%Prismatic.Context{} = context) do
    app_config = Application.get_env(@app, @config_key)
    context_config = Keyword.get(context.req_options, @config_key, [])

    merge_config(app_config, context_config)
  end

  defp merge_config(nil, context_config), do: context_config
  defp merge_config(app_config, []), do: app_config

  defp merge_config(app_config, context_config)
       when (is_list(app_config) or is_map(app_config)) and
              (is_list(context_config) or is_map(context_config)) do
    app_profiles = config_value(app_config, :profiles, %{})
    context_profiles = config_value(context_config, :profiles, %{})

    app_config
    |> to_map()
    |> Map.merge(to_map(context_config))
    |> Map.put(:profiles, Map.merge(to_map(app_profiles), to_map(context_profiles)))
  end

  defp merge_config(_app_config, context_config), do: context_config

  defp normalize_overrides!(overrides) when is_map(overrides), do: overrides

  defp normalize_overrides!(overrides) when is_list(overrides) do
    if Keyword.keyword?(overrides) do
      Map.new(overrides)
    else
      raise ArgumentError, "expected keyword overrides, got: #{inspect(overrides)}"
    end
  end

  defp normalize_overrides!(overrides) do
    raise ArgumentError, "expected map or keyword overrides, got: #{inspect(overrides)}"
  end

  defp reject_public_simulation_selector(values) when is_list(values) do
    if Enum.any?(values, &public_simulation_entry?/1) do
      {:error, {:public_simulation_selector_forbidden, :prismatic}}
    else
      :ok
    end
  end

  defp reject_public_simulation_selector(values) when is_map(values) do
    if Map.has_key?(values, :simulation) or Map.has_key?(values, "simulation") do
      {:error, {:public_simulation_selector_forbidden, :prismatic}}
    else
      :ok
    end
  end

  defp reject_public_simulation_selector(_values), do: :ok

  defp public_simulation_entry?({key, _value}), do: key in [:simulation, "simulation"]
  defp public_simulation_entry?(_entry), do: false

  defp required?(config) do
    case config_value(config, :required?, true) do
      value when is_boolean(value) -> {:ok, value}
      other -> {:error, {:invalid_prismatic_simulation_required?, other}}
    end
  end

  defp configured_profile(config, keys) do
    profiles = config_value(config, :profiles, %{})

    profile =
      Enum.find_value(keys, fn key ->
        case config_value(profiles, key, @missing) do
          @missing -> nil
          value -> value
        end
      end)

    case profile do
      nil -> {:missing, keys}
      false -> {:missing, keys}
      profile when is_list(profile) or is_map(profile) -> {:ok, profile}
      other -> {:error, {:invalid_prismatic_simulation_profile, other}}
    end
  end

  defp normalize_profile(profile) do
    with :ok <- reject_public_simulation_selector(profile),
         {:ok, scenario_ref} <- required_string(profile, :scenario_ref),
         {:ok, body} <- response_body(profile),
         {:ok, status_code} <- status_code(profile),
         {:ok, headers} <- headers(profile),
         {:ok, outcome_status} <- outcome_status(profile),
         {:ok, side_effect_policy} <- side_effect_policy(profile),
         {:ok, metrics} <- metrics(profile),
         {:ok, failure} <- failure(profile) do
      {:ok,
       [
         scenario_ref: scenario_ref,
         status_code: status_code,
         headers: headers,
         body: body,
         outcome_status: outcome_status,
         side_effect_policy: side_effect_policy,
         metrics: metrics
       ]
       |> maybe_put(:failure, failure)}
    end
  end

  defp response_body(profile) do
    profile
    |> profile_value(
      :body,
      profile_value(profile, :response, profile_value(profile, :graphql_response, @missing))
    )
    |> encode_body()
  end

  defp encode_body(value) when is_binary(value) and value != "", do: {:ok, value}

  defp encode_body(value) when is_map(value) or is_list(value) do
    Jason.encode(value)
  end

  defp encode_body(@missing), do: {:error, {:missing_required_option, :body}}
  defp encode_body(other), do: {:error, {:invalid_graphql_body, other}}

  defp status_code(profile) do
    case profile_value(profile, :status_code, profile_value(profile, :http_status, 200)) do
      status when is_integer(status) and status >= 100 and status <= 599 -> {:ok, status}
      other -> {:error, {:invalid_status_code, other}}
    end
  end

  defp headers(profile) do
    headers =
      profile
      |> profile_value(:headers, %{})
      |> normalize_headers()

    case headers do
      %{} = headers -> {:ok, Map.put_new(headers, "content-type", "application/json")}
      {:error, _reason} = error -> error
    end
  end

  defp outcome_status(profile) do
    case profile_value(
           profile,
           :outcome_status,
           profile_value(profile, :simulation_status, "succeeded")
         ) do
      value when value in ["succeeded", "failed"] -> {:ok, value}
      other -> {:error, {:invalid_outcome_status, other}}
    end
  end

  defp side_effect_policy(profile) do
    case profile_value(profile, :side_effect_policy, @default_side_effect_policy) do
      value when is_binary(value) -> {:ok, value}
      other -> {:error, {:invalid_side_effect_policy, other}}
    end
  end

  defp metrics(profile) do
    case profile_value(profile, :metrics, %{"duration_ms" => 0}) do
      metrics when is_map(metrics) -> {:ok, stringify_keys(metrics)}
      other -> {:error, {:invalid_metrics, other}}
    end
  end

  defp failure(profile) do
    case profile_value(profile, :failure, nil) do
      nil -> {:ok, nil}
      failure when is_map(failure) -> {:ok, stringify_keys(failure)}
      other -> {:error, {:invalid_failure, other}}
    end
  end

  defp required_string(profile, key) do
    case profile_value(profile, key, @missing) do
      value when is_binary(value) and value != "" -> {:ok, value}
      @missing -> {:error, {:missing_required_option, key}}
      other -> {:error, {:invalid_string_option, key, other}}
    end
  end

  defp build_request(payload, %Prismatic.Context{} = context, endpoint_id, request_opts) do
    %Request{
      method: :post,
      url: context.base_url,
      headers: normalize_headers(context.headers),
      body: payload,
      endpoint_id: endpoint_id,
      metadata: request_metadata(context, endpoint_id, request_opts)
    }
  end

  defp request_metadata(%Prismatic.Context{} = context, endpoint_id, opts) do
    %{
      endpoint_id: endpoint_id,
      operation_name: endpoint_id,
      base_url: context.base_url,
      path: URI.parse(context.base_url).path || "/graphql"
    }
    |> maybe_put(:timeout, timeout_ms(opts))
  end

  defp profile_keys(payload) do
    operation_name = payload["operationName"] || payload[:operationName]

    [
      operation_name,
      operation_name && "operation:#{operation_name}",
      "anonymous",
      :default
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&normalize_key/1)
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(nil), do: {:ok, %{}}
  defp decode_body(""), do: {:ok, %{}}

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, decoded} -> {:error, {:invalid_graphql_response_body, decoded}}
      {:error, reason} -> {:error, {:invalid_graphql_response_body, reason}}
    end
  end

  defp decode_body(body), do: {:error, {:invalid_graphql_response_body, body}}

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  rescue
    ArgumentError -> {:error, {:invalid_headers, headers}}
  end

  defp normalize_headers(headers), do: {:error, {:invalid_headers, headers}}

  defp normalize_response_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_response_headers(headers) when is_list(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_response_headers(_headers), do: []

  defp timeout_ms(opts) do
    Enum.find_value([:receive_timeout, :timeout_ms, :timeout], fn key ->
      case Keyword.get(opts, key) do
        value when is_integer(value) and value > 0 -> value
        _other -> nil
      end
    end)
  end

  defp profile_value(profile, key, default) do
    config_value(profile, key, default)
  end

  defp config_value(nil, _key, default), do: default

  defp config_value(config, key, default) when is_list(config) do
    case Enum.find(config, &matching_key?(&1, key)) do
      {_key, value} -> value
      nil -> default
    end
  end

  defp config_value(config, key, default) when is_map(config) do
    Map.get(config, key, Map.get(config, to_string(key), default))
  end

  defp config_value(_config, _key, default), do: default

  defp matching_key?({entry_key, _value}, key) do
    normalize_key(entry_key) == normalize_key(key)
  end

  defp matching_key?(_entry, _key), do: false

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: to_string(key)

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp to_map(nil), do: %{}

  defp to_map(config) when is_list(config) do
    if Keyword.keyword?(config) do
      Map.new(config)
    else
      Map.new(config, fn {key, value} -> {key, value} end)
    end
  end

  defp to_map(config) when is_map(config), do: config
  defp to_map(_config), do: %{}

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value) when is_list(opts), do: Keyword.put(opts, key, value)
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
