defmodule PrismaticCodegen.Source.Documents do
  @moduledoc """
  Curated GraphQL document loader for provider repositories.
  """

  alias PrismaticCodegen.ProviderIR

  @operation_regex ~r/\b(query|mutation)\s+([_A-Za-z][_0-9A-Za-z]*)/
  @root_field_regex ~r/\{\s*([_A-Za-z][_0-9A-Za-z]*)/

  @spec load!(Path.t()) :: [ProviderIR.Document.t()]
  def load!(documents_root) do
    documents_root
    |> collect_files()
    |> Enum.map(&load_document!(documents_root, &1))
  end

  defp collect_files(documents_root) do
    documents_root
    |> Path.join("**/*.{graphql,gql}")
    |> Path.wildcard()
    |> Enum.sort()
    |> case do
      [] -> raise ArgumentError, "no graphql documents found in #{documents_root}"
      files -> files
    end
  end

  defp load_document!(documents_root, path) do
    document = File.read!(path)
    {kind, name} = parse_operation_header!(document, path)
    root_field = parse_root_field!(document, path)

    %ProviderIR.Document{
      id: Macro.underscore(name),
      name: name,
      kind: kind,
      path: path,
      relative_path: Path.relative_to(path, documents_root),
      document: document,
      root_field: root_field
    }
  end

  defp parse_operation_header!(document, path) do
    case Regex.run(@operation_regex, document, capture: :all_but_first) do
      ["query", name] -> {:query, name}
      ["mutation", name] -> {:mutation, name}
      _other -> raise ArgumentError, "document #{path} must declare a named query or mutation"
    end
  end

  defp parse_root_field!(document, path) do
    case Regex.run(@root_field_regex, document, capture: :all_but_first) do
      [root_field] -> root_field
      _other -> raise ArgumentError, "document #{path} must contain a root selection"
    end
  end
end
