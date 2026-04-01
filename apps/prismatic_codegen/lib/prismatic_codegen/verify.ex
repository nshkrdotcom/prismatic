defmodule PrismaticCodegen.Verify do
  @moduledoc """
  Freshness verification for generated provider artifacts.
  """

  alias PrismaticCodegen.Compiler
  alias PrismaticCodegen.Provider

  @spec stale_files(Provider.t() | module() | String.t()) :: [Path.t()]
  def stale_files(provider) do
    provider = Provider.load!(provider)

    expected =
      provider
      |> Compiler.render!()
      |> Map.new(fn file -> {file.path, file.content} end)

    Enum.reduce(expected, [], fn {relative_path, expected_content}, stale ->
      full_path = Path.join(provider.output.root, relative_path)

      case File.read(full_path) do
        {:ok, ^expected_content} -> stale
        _other -> [relative_path | stale]
      end
    end)
    |> Enum.reverse()
  end

  @spec assert_current!(Provider.t() | module() | String.t()) :: :ok
  def assert_current!(provider) do
    case stale_files(provider) do
      [] -> :ok
      stale -> raise ArgumentError, "stale generated artifacts: #{Enum.join(stale, ", ")}"
    end
  end
end
