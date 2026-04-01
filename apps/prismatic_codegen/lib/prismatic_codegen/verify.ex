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

    mismatched =
      Enum.reduce(expected, [], fn {relative_path, expected_content}, stale ->
        full_path = Path.join(provider.output.root, relative_path)

        case File.read(full_path) do
          {:ok, ^expected_content} -> stale
          _other -> [relative_path | stale]
        end
      end)

    unexpected =
      provider
      |> managed_files()
      |> Enum.reject(&Map.has_key?(expected, &1))

    mismatched
    |> Enum.reverse()
    |> Kernel.++(unexpected)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec assert_current!(Provider.t() | module() | String.t()) :: :ok
  def assert_current!(provider) do
    case stale_files(provider) do
      [] -> :ok
      stale -> raise ArgumentError, "stale generated artifacts: #{Enum.join(stale, ", ")}"
    end
  end

  defp managed_files(provider) do
    root = provider.output.root
    lib_dir = Path.join(root, provider.output.lib_root)
    docs_dir = Path.join(root, provider.output.docs_root)
    namespace_root = Path.join(root, "#{provider.output.lib_root}.ex")

    [
      namespace_root
      | managed_directory_files(lib_dir) ++ managed_directory_files(docs_dir)
    ]
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.sort()
  end

  defp managed_directory_files(path) do
    path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
  end
end
