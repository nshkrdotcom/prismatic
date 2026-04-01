defmodule PrismaticProviderTestkit.Artifacts do
  @moduledoc """
  Simple freshness helpers for generated artifacts.
  """

  @spec stale_files(%{Path.t() => binary()}, Path.t()) :: [Path.t()]
  def stale_files(expected_files, root) do
    Enum.reduce(expected_files, [], fn {relative_path, expected_content}, stale ->
      full_path = Path.join(root, relative_path)

      case File.read(full_path) do
        {:ok, ^expected_content} -> stale
        _other -> [relative_path | stale]
      end
    end)
    |> Enum.reverse()
  end

  @spec assert_current!(%{Path.t() => binary()}, Path.t()) :: :ok
  def assert_current!(expected_files, root) do
    case stale_files(expected_files, root) do
      [] -> :ok
      stale -> raise ArgumentError, "stale generated artifacts: #{Enum.join(stale, ", ")}"
    end
  end
end
