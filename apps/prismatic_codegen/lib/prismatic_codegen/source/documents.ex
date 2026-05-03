defmodule PrismaticCodegen.Source.Documents do
  @moduledoc """
  Curated GraphQL document loader for provider repositories.
  """

  alias PrismaticCodegen.ProviderIR

  @operation_kinds %{"query" => :query, "mutation" => :mutation}

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
    tokens = tokenize!(document, path)
    fragments = collect_fragments(tokens, %{}, path)
    {kind, name, selection} = operation_selection!(tokens, path)
    root_field = root_field!(selection, fragments, path)

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

  defp collect_fragments([], fragments, _path), do: fragments

  defp collect_fragments([{:name, "fragment"}, {:name, name} | rest], fragments, path) do
    {selection, remaining} =
      rest
      |> skip_to_selection_set!(path)
      |> take_selection_set!(path)

    collect_fragments(remaining, Map.put(fragments, name, selection), path)
  end

  defp collect_fragments([{:name, kind} | rest], fragments, path)
       when kind in ["query", "mutation", "subscription"] do
    {_selection, remaining} =
      rest
      |> skip_to_selection_set!(path)
      |> take_selection_set!(path)

    collect_fragments(remaining, fragments, path)
  end

  defp collect_fragments([{:punctuator, "{"} | _rest] = tokens, fragments, path) do
    {_selection, remaining} = take_selection_set!(tokens, path)
    collect_fragments(remaining, fragments, path)
  end

  defp collect_fragments([_token | rest], fragments, path),
    do: collect_fragments(rest, fragments, path)

  defp operation_selection!([], path) do
    raise ArgumentError, "document #{path} must declare a named query or mutation"
  end

  defp operation_selection!([{:name, kind} | rest], path)
       when is_map_key(@operation_kinds, kind) do
    {name, after_name} = operation_name!(rest, path)

    {selection, _remaining} =
      after_name
      |> skip_to_selection_set!(path)
      |> take_selection_set!(path)

    {Map.fetch!(@operation_kinds, kind), name, selection}
  end

  defp operation_selection!([{:name, "fragment"}, {:name, _name} | rest], path) do
    {_selection, remaining} =
      rest
      |> skip_to_selection_set!(path)
      |> take_selection_set!(path)

    operation_selection!(remaining, path)
  end

  defp operation_selection!([{:name, "subscription"} | rest], path) do
    {_selection, remaining} =
      rest
      |> skip_to_selection_set!(path)
      |> take_selection_set!(path)

    operation_selection!(remaining, path)
  end

  defp operation_selection!([{:punctuator, "{"} | _rest], path) do
    raise ArgumentError, "document #{path} must declare a named query or mutation"
  end

  defp operation_selection!([_token | rest], path), do: operation_selection!(rest, path)

  defp operation_name!([{:name, name} | rest], _path), do: {name, rest}

  defp operation_name!(_tokens, path) do
    raise ArgumentError, "document #{path} must declare a named query or mutation"
  end

  defp root_field!(selection, fragments, path) do
    case root_field_from_selection(selection, fragments, path, []) do
      {:ok, field} -> field
      :error -> raise ArgumentError, "document #{path} must contain a root selection"
    end
  end

  defp root_field_from_selection([], _fragments, _path, _visited), do: :error

  defp root_field_from_selection(
         [{:punctuator, "..."}, {:name, "on"} | rest],
         fragments,
         path,
         visited
       ) do
    {selection, remaining} =
      rest
      |> skip_to_selection_set!(path)
      |> take_selection_set!(path)

    case root_field_from_selection(selection, fragments, path, visited) do
      {:ok, field} -> {:ok, field}
      :error -> root_field_from_selection(remaining, fragments, path, visited)
    end
  end

  defp root_field_from_selection(
         [{:punctuator, "..."}, {:name, fragment_name} | rest],
         fragments,
         path,
         visited
       ) do
    cond do
      fragment_name in visited ->
        root_field_from_selection(rest, fragments, path, visited)

      Map.has_key?(fragments, fragment_name) ->
        selection = Map.fetch!(fragments, fragment_name)

        case root_field_from_selection(selection, fragments, path, [fragment_name | visited]) do
          {:ok, field} -> {:ok, field}
          :error -> root_field_from_selection(rest, fragments, path, visited)
        end

      true ->
        root_field_from_selection(rest, fragments, path, visited)
    end
  end

  defp root_field_from_selection(
         [{:name, _alias}, {:punctuator, ":"}, {:name, field} | _rest],
         _fragments,
         _path,
         _visited
       ),
       do: {:ok, field}

  defp root_field_from_selection([{:name, field} | _rest], _fragments, _path, _visited),
    do: {:ok, field}

  defp root_field_from_selection([{:punctuator, "{"} | _rest] = tokens, fragments, path, visited) do
    {_selection, remaining} = take_selection_set!(tokens, path)
    root_field_from_selection(remaining, fragments, path, visited)
  end

  defp root_field_from_selection([_token | rest], fragments, path, visited),
    do: root_field_from_selection(rest, fragments, path, visited)

  defp skip_to_selection_set!(tokens, path), do: skip_to_selection_set!(tokens, 0, 0, path)

  defp skip_to_selection_set!([], _paren_depth, _bracket_depth, path) do
    raise ArgumentError, "document #{path} operation definition is missing a selection set"
  end

  defp skip_to_selection_set!([{:punctuator, "("} | rest], paren_depth, bracket_depth, path),
    do: skip_to_selection_set!(rest, paren_depth + 1, bracket_depth, path)

  defp skip_to_selection_set!([{:punctuator, ")"} | rest], paren_depth, bracket_depth, path)
       when paren_depth > 0,
       do: skip_to_selection_set!(rest, paren_depth - 1, bracket_depth, path)

  defp skip_to_selection_set!([{:punctuator, "["} | rest], paren_depth, bracket_depth, path),
    do: skip_to_selection_set!(rest, paren_depth, bracket_depth + 1, path)

  defp skip_to_selection_set!([{:punctuator, "]"} | rest], paren_depth, bracket_depth, path)
       when bracket_depth > 0,
       do: skip_to_selection_set!(rest, paren_depth, bracket_depth - 1, path)

  defp skip_to_selection_set!([{:punctuator, "{"} | _rest] = tokens, 0, 0, _path), do: tokens

  defp skip_to_selection_set!([_token | rest], paren_depth, bracket_depth, path),
    do: skip_to_selection_set!(rest, paren_depth, bracket_depth, path)

  defp take_selection_set!([{:punctuator, "{"} | rest], path),
    do: take_selection_set!(rest, 1, [], path)

  defp take_selection_set!(_tokens, path) do
    raise ArgumentError, "document #{path} operation definition is missing a selection set"
  end

  defp take_selection_set!([], _depth, _selection, path) do
    raise ArgumentError, "document #{path} selection set is not balanced"
  end

  defp take_selection_set!([{:punctuator, "{"} = token | rest], depth, selection, path),
    do: take_selection_set!(rest, depth + 1, [token | selection], path)

  defp take_selection_set!([{:punctuator, "}"} | rest], 1, selection, _path),
    do: {Enum.reverse(selection), rest}

  defp take_selection_set!([{:punctuator, "}"} = token | rest], depth, selection, path),
    do: take_selection_set!(rest, depth - 1, [token | selection], path)

  defp take_selection_set!([token | rest], depth, selection, path),
    do: take_selection_set!(rest, depth, [token | selection], path)

  defp tokenize!(document, path), do: tokenize!(document, [], path)

  defp tokenize!(<<>>, tokens, _path), do: Enum.reverse(tokens)
  defp tokenize!(<<"\uFEFF", rest::binary>>, tokens, path), do: tokenize!(rest, tokens, path)

  defp tokenize!(<<char, rest::binary>>, tokens, path) when char in [?\s, ?\n, ?\r, ?\t, ?\f, ?,],
    do: tokenize!(rest, tokens, path)

  defp tokenize!(<<"#", rest::binary>>, tokens, path),
    do: tokenize!(consume_comment(rest), tokens, path)

  defp tokenize!(<<"\"\"\"", rest::binary>>, tokens, path),
    do: tokenize!(consume_block_string!(rest, path), tokens, path)

  defp tokenize!(<<"\"", rest::binary>>, tokens, path),
    do: tokenize!(consume_string!(rest, path), tokens, path)

  defp tokenize!(<<"...", rest::binary>>, tokens, path),
    do: tokenize!(rest, [{:punctuator, "..."} | tokens], path)

  defp tokenize!(<<char, rest::binary>>, tokens, path)
       when char in [?!, ?$, ?&, ?(, ?), ?:, ?=, ?@, ?[, ?], ?{, ?|, ?}] do
    tokenize!(rest, [{:punctuator, <<char>>} | tokens], path)
  end

  defp tokenize!(<<char, _rest::binary>> = document, tokens, path)
       when char in ?A..?Z or char in ?a..?z or char == ?_ do
    {name, rest} = consume_name(document)
    tokenize!(rest, [{:name, name} | tokens], path)
  end

  defp tokenize!(<<char, _rest::binary>> = document, tokens, path)
       when char in ?0..?9 or char == ?- do
    {_number, rest} = consume_number!(document, path)
    tokenize!(rest, tokens, path)
  end

  defp tokenize!(<<char::utf8, _rest::binary>>, _tokens, path) do
    raise ArgumentError,
          "document #{path} contains unsupported GraphQL token #{inspect(<<char::utf8>>)}"
  end

  defp consume_comment(<<"\n", rest::binary>>), do: rest
  defp consume_comment(<<"\r\n", rest::binary>>), do: rest
  defp consume_comment(<<"\r", rest::binary>>), do: rest
  defp consume_comment(<<_char::utf8, rest::binary>>), do: consume_comment(rest)
  defp consume_comment(<<>>), do: <<>>

  defp consume_string!(<<>>, path),
    do: raise(ArgumentError, "document #{path} has an unterminated GraphQL string literal")

  defp consume_string!(<<"\\", _escaped::utf8, rest::binary>>, path),
    do: consume_string!(rest, path)

  defp consume_string!(<<"\"", rest::binary>>, _path), do: rest
  defp consume_string!(<<_char::utf8, rest::binary>>, path), do: consume_string!(rest, path)

  defp consume_block_string!(<<>>, path),
    do: raise(ArgumentError, "document #{path} has an unterminated GraphQL block string literal")

  defp consume_block_string!(<<"\\\"\"\"", rest::binary>>, path),
    do: consume_block_string!(rest, path)

  defp consume_block_string!(<<"\"\"\"", rest::binary>>, _path), do: rest

  defp consume_block_string!(<<_char::utf8, rest::binary>>, path),
    do: consume_block_string!(rest, path)

  defp consume_name(document), do: consume_name(document, [])

  defp consume_name(<<char, rest::binary>>, chars)
       when char in ?A..?Z or char in ?a..?z or char in ?0..?9 or char == ?_ do
    consume_name(rest, [char | chars])
  end

  defp consume_name(rest, chars), do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp consume_number!(document, path), do: consume_number!(document, [], path)

  defp consume_number!(<<"-", rest::binary>>, [], path),
    do: consume_negative_number!(rest, [?-], path)

  defp consume_number!(<<char, rest::binary>>, chars, path) when char in ?0..?9,
    do: consume_number!(rest, [char | chars], path)

  defp consume_number!(<<".", rest::binary>>, chars, path),
    do: consume_fractional_number!(rest, [?. | chars], path)

  defp consume_number!(<<char, rest::binary>>, chars, path) when char in [?e, ?E],
    do: consume_exponent_number!(rest, [char | chars], path)

  defp consume_number!(rest, chars, _path),
    do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp consume_negative_number!(<<char, rest::binary>>, chars, path) when char in ?0..?9,
    do: consume_number!(rest, [char | chars], path)

  defp consume_negative_number!(_rest, _chars, path),
    do: raise(ArgumentError, "document #{path} has an invalid GraphQL number literal")

  defp consume_fractional_number!(<<char, rest::binary>>, chars, path) when char in ?0..?9,
    do: consume_fractional_digits!(rest, [char | chars], path)

  defp consume_fractional_number!(_rest, _chars, path),
    do: raise(ArgumentError, "document #{path} has an invalid GraphQL number literal")

  defp consume_fractional_digits!(<<char, rest::binary>>, chars, path) when char in ?0..?9,
    do: consume_fractional_digits!(rest, [char | chars], path)

  defp consume_fractional_digits!(<<char, rest::binary>>, chars, path) when char in [?e, ?E],
    do: consume_exponent_number!(rest, [char | chars], path)

  defp consume_fractional_digits!(rest, chars, _path),
    do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp consume_exponent_number!(<<sign, rest::binary>>, chars, path) when sign in [?+, ?-],
    do: consume_exponent_digits!(rest, [sign | chars], path)

  defp consume_exponent_number!(rest, chars, path),
    do: consume_exponent_digits!(rest, chars, path)

  defp consume_exponent_digits!(<<char, rest::binary>>, chars, path) when char in ?0..?9,
    do: consume_exponent_digits!(rest, [char | chars], path)

  defp consume_exponent_digits!(_rest, _chars, path),
    do: raise(ArgumentError, "document #{path} has an invalid GraphQL number literal")
end
