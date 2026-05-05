defmodule PrismaticCodegen.ModuleNames do
  @moduledoc false

  @spec generated!(module(), [String.t()]) :: module()
  def generated!(namespace, segments) when is_atom(namespace) and is_list(segments) do
    safe_segments = Enum.map(segments, &module_segment!/1)
    :erlang.apply(Module, :concat, [[namespace | safe_segments]])
  end

  @spec existing!([String.t()]) :: module()
  def existing!(segments) when is_list(segments) do
    segments
    |> Enum.map(&existing_segment!/1)
    |> Module.safe_concat()
  end

  defp module_segment!(name) when is_binary(name) do
    name
    |> Macro.camelize()
    |> validate_segment!(name)
  end

  defp module_segment!(name) do
    raise ArgumentError, "module segment must be a string, got #{inspect(name)}"
  end

  defp existing_segment!(name) when is_binary(name), do: validate_segment!(name, name)

  defp existing_segment!(name) do
    raise ArgumentError, "existing module segment must be a string, got #{inspect(name)}"
  end

  defp validate_segment!(segment, original) do
    if valid_segment?(segment) do
      segment
    else
      raise ArgumentError,
            "invalid generated module segment #{inspect(original)} resolved to #{inspect(segment)}"
    end
  end

  defp valid_segment?(<<first, rest::binary>>) when first in ?A..?Z do
    valid_segment_rest?(rest)
  end

  defp valid_segment?(_segment), do: false

  defp valid_segment_rest?(<<>>), do: true

  defp valid_segment_rest?(<<char, rest::binary>>)
       when char in ?A..?Z or char in ?a..?z or char in ?0..?9 do
    valid_segment_rest?(rest)
  end

  defp valid_segment_rest?(_rest), do: false
end
