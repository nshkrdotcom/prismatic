defmodule Prismatic.Telemetry do
  @moduledoc false

  @spec span([atom()], map(), (-> term())) :: term()
  def span(prefix, metadata, fun) do
    start_event = prefix ++ [:start]
    stop_event = prefix ++ [:stop]
    exception_event = prefix ++ [:exception]
    start_time = System.monotonic_time()

    :telemetry.execute(start_event, %{system_time: System.system_time()}, metadata)

    try do
      result = fun.()

      :telemetry.execute(
        stop_event,
        %{duration: System.monotonic_time() - start_time},
        metadata
      )

      result
    rescue
      error ->
        :telemetry.execute(
          exception_event,
          %{duration: System.monotonic_time() - start_time},
          Map.put(metadata, :error, error)
        )

        reraise error, __STACKTRACE__
    end
  end
end
