defmodule PrismaticCodegen.Verify do
  @moduledoc """
  Freshness verification for generated provider artifacts.
  """

  alias PrismaticCodegen.Compiler
  alias PrismaticCodegen.Provider
  alias PrismaticCodegen.Render.ElixirSDK.PublicSchemaModules

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
    public_managed_roots = PublicSchemaModules.managed_roots(provider)

    [
      namespace_root
      | managed_directory_files(lib_dir) ++
          managed_directory_files(docs_dir) ++
          managed_public_files(root, public_managed_roots)
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

  defp managed_public_files(root, managed_roots) do
    Enum.flat_map(managed_roots, fn relative_path ->
      path = Path.join(root, relative_path)

      cond do
        File.regular?(path) -> [path]
        File.dir?(path) -> managed_directory_files(path)
        true -> []
      end
    end)
  end
end
