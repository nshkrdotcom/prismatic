defmodule Prismatic.GraphQL.Document do
  @moduledoc false

  @type operation_kind :: :query | :mutation | :subscription

  @type operation_metadata :: %{
          kind: operation_kind(),
          name: String.t() | nil
        }

  @spec select_operation!(String.t(), String.t() | nil) :: operation_metadata()
  def select_operation!(document, requested_name \\ nil)
      when is_binary(document) and (is_binary(requested_name) or is_nil(requested_name)) do
    document
    |> tokenize!()
    |> parse_operations!()
    |> pick_operation!(normalize_requested_name(requested_name))
  end

  defp normalize_requested_name(nil), do: nil

  defp normalize_requested_name(requested_name) when is_binary(requested_name) do
    case String.trim(requested_name) do
      "" -> raise ArgumentError, "operation_name must not be blank"
      trimmed -> trimmed
    end
  end

  defp pick_operation!([], _requested_name) do
    raise ArgumentError, "document does not declare an executable GraphQL operation"
  end

  defp pick_operation!([operation], nil), do: operation

  defp pick_operation!(operations, nil) when is_list(operations) do
    raise ArgumentError,
          "document declares multiple operations; pass operation_name: \"...\" to select one"
  end

  defp pick_operation!(operations, requested_name) when is_list(operations) do
    case Enum.filter(operations, &(&1.name == requested_name)) do
      [operation] ->
        operation

      [] ->
        raise ArgumentError, "operation #{inspect(requested_name)} does not exist in document"

      _many ->
        raise ArgumentError,
              "document declares duplicate operations named #{inspect(requested_name)}"
    end
  end

  defp parse_operations!(tokens), do: parse_operations!(tokens, [])

  defp parse_operations!([], operations), do: Enum.reverse(operations)

  defp parse_operations!([{:punctuator, "{"} | rest], operations) do
    rest
    |> skip_selection_set!(1)
    |> parse_operations!([%{kind: :query, name: nil} | operations])
  end

  defp parse_operations!([{:name, "query"} | rest], operations) do
    parse_named_operation!(:query, rest, operations)
  end

  defp parse_operations!([{:name, "mutation"} | rest], operations) do
    parse_named_operation!(:mutation, rest, operations)
  end

  defp parse_operations!([{:name, "subscription"} | rest], operations) do
    parse_named_operation!(:subscription, rest, operations)
  end

  defp parse_operations!([{:name, "fragment"} | rest], operations) do
    rest
    |> skip_to_selection_set!()
    |> skip_selection_set!(1)
    |> parse_operations!(operations)
  end

  defp parse_operations!([{:name, name} | _rest], _operations) do
    raise ArgumentError,
          "unsupported top-level GraphQL definition starting with #{inspect(name)}"
  end

  defp parse_operations!([token | _rest], _operations) do
    raise ArgumentError, "unexpected top-level GraphQL token #{inspect(token)}"
  end

  defp parse_named_operation!(kind, tokens, operations) do
    {name, tokens} =
      case tokens do
        [{:name, name} | rest] -> {name, rest}
        _other -> {nil, tokens}
      end

    tokens
    |> skip_to_selection_set!()
    |> skip_selection_set!(1)
    |> parse_operations!([%{kind: kind, name: name} | operations])
  end

  defp skip_to_selection_set!(tokens), do: skip_to_selection_set!(tokens, 0, 0)

  defp skip_to_selection_set!([], _paren_depth, _bracket_depth) do
    raise ArgumentError, "operation definition is missing a selection set"
  end

  defp skip_to_selection_set!([{:punctuator, "("} | rest], paren_depth, bracket_depth) do
    skip_to_selection_set!(rest, paren_depth + 1, bracket_depth)
  end

  defp skip_to_selection_set!([{:punctuator, ")"} | rest], paren_depth, bracket_depth)
       when paren_depth > 0 do
    skip_to_selection_set!(rest, paren_depth - 1, bracket_depth)
  end

  defp skip_to_selection_set!([{:punctuator, "["} | rest], paren_depth, bracket_depth) do
    skip_to_selection_set!(rest, paren_depth, bracket_depth + 1)
  end

  defp skip_to_selection_set!([{:punctuator, "]"} | rest], paren_depth, bracket_depth)
       when bracket_depth > 0 do
    skip_to_selection_set!(rest, paren_depth, bracket_depth - 1)
  end

  defp skip_to_selection_set!([{:punctuator, "{"} | rest], 0, 0), do: rest

  defp skip_to_selection_set!([_token | rest], paren_depth, bracket_depth),
    do: skip_to_selection_set!(rest, paren_depth, bracket_depth)

  defp skip_selection_set!([], _depth) do
    raise ArgumentError, "selection set is not balanced"
  end

  defp skip_selection_set!([{:punctuator, "{"} | rest], depth),
    do: skip_selection_set!(rest, depth + 1)

  defp skip_selection_set!([{:punctuator, "}"} | rest], 1), do: rest

  defp skip_selection_set!([{:punctuator, "}"} | rest], depth),
    do: skip_selection_set!(rest, depth - 1)

  defp skip_selection_set!([_token | rest], depth), do: skip_selection_set!(rest, depth)

  defp tokenize!(document), do: tokenize!(document, [])

  defp tokenize!(<<>>, tokens), do: Enum.reverse(tokens)
  defp tokenize!(<<"\uFEFF", rest::binary>>, tokens), do: tokenize!(rest, tokens)

  defp tokenize!(<<char, rest::binary>>, tokens) when char in [?\s, ?\n, ?\r, ?\t, ?\f, ?,],
    do: tokenize!(rest, tokens)

  defp tokenize!(<<"#", rest::binary>>, tokens) do
    tokenize!(consume_comment(rest), tokens)
  end

  defp tokenize!(<<"\"\"\"", rest::binary>>, tokens) do
    tokenize!(consume_block_string!(rest), tokens)
  end

  defp tokenize!(<<"\"", rest::binary>>, tokens) do
    tokenize!(consume_string!(rest), tokens)
  end

  defp tokenize!(<<"...", rest::binary>>, tokens),
    do: tokenize!(rest, [{:punctuator, "..."} | tokens])

  defp tokenize!(<<char, rest::binary>>, tokens)
       when char in [?!, ?$, ?&, ?(, ?), ?:, ?=, ?@, ?[, ?], ?{, ?|, ?}] do
    tokenize!(rest, [{:punctuator, <<char>>} | tokens])
  end

  defp tokenize!(<<char, _rest::binary>> = document, tokens)
       when char in ?A..?Z or char in ?a..?z or char == ?_ do
    {name, rest} = consume_name(document)
    tokenize!(rest, [{:name, name} | tokens])
  end

  defp tokenize!(<<char, _rest::binary>> = document, tokens) when char in ?0..?9 or char == ?- do
    {number, rest} = consume_number!(document)
    tokenize!(rest, [{:number, number} | tokens])
  end

  defp tokenize!(<<char::utf8, _rest::binary>>, _tokens) do
    raise ArgumentError, "unsupported GraphQL token starting with #{inspect(<<char::utf8>>)}"
  end

  defp consume_comment(<<"\n", rest::binary>>), do: rest
  defp consume_comment(<<"\r\n", rest::binary>>), do: rest
  defp consume_comment(<<"\r", rest::binary>>), do: rest
  defp consume_comment(<<_char::utf8, rest::binary>>), do: consume_comment(rest)
  defp consume_comment(<<>>), do: <<>>

  defp consume_string!(<<>>), do: raise(ArgumentError, "unterminated GraphQL string literal")
  defp consume_string!(<<"\\", _escaped::utf8, rest::binary>>), do: consume_string!(rest)
  defp consume_string!(<<"\"", rest::binary>>), do: rest
  defp consume_string!(<<_char::utf8, rest::binary>>), do: consume_string!(rest)

  defp consume_block_string!(<<>>),
    do: raise(ArgumentError, "unterminated GraphQL block string literal")

  defp consume_block_string!(<<"\\\"\"\"", rest::binary>>) do
    consume_block_string!(rest)
  end

  defp consume_block_string!(<<"\"\"\"", rest::binary>>), do: rest
  defp consume_block_string!(<<_char::utf8, rest::binary>>), do: consume_block_string!(rest)

  defp consume_name(document), do: consume_name(document, [])

  defp consume_name(<<char, rest::binary>>, chars)
       when char in ?A..?Z or char in ?a..?z or char in ?0..?9 or char == ?_ do
    consume_name(rest, [char | chars])
  end

  defp consume_name(rest, chars), do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp consume_number!(document), do: consume_number!(document, [])

  defp consume_number!(<<"-", rest::binary>>, []) do
    consume_negative_number!(rest, [?-])
  end

  defp consume_number!(<<char, rest::binary>>, chars) when char in ?0..?9 do
    consume_number!(rest, [char | chars])
  end

  defp consume_number!(<<".", rest::binary>>, chars) do
    consume_fractional_number!(rest, [?. | chars])
  end

  defp consume_number!(<<char, rest::binary>>, chars) when char in [?e, ?E] do
    consume_exponent_number!(rest, [char | chars])
  end

  defp consume_number!(rest, chars), do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp consume_negative_number!(<<char, rest::binary>>, chars) when char in ?0..?9 do
    consume_number!(rest, [char | chars])
  end

  defp consume_negative_number!(_rest, _chars) do
    raise ArgumentError, "invalid GraphQL numeric literal"
  end

  defp consume_fractional_number!(<<char, rest::binary>>, chars) when char in ?0..?9 do
    consume_fractional_number_digits!(rest, [char | chars])
  end

  defp consume_fractional_number!(_rest, _chars) do
    raise ArgumentError, "invalid GraphQL numeric literal"
  end

  defp consume_fractional_number_digits!(<<char, rest::binary>>, chars) when char in ?0..?9 do
    consume_fractional_number_digits!(rest, [char | chars])
  end

  defp consume_fractional_number_digits!(<<char, rest::binary>>, chars) when char in [?e, ?E] do
    consume_exponent_number!(rest, [char | chars])
  end

  defp consume_fractional_number_digits!(rest, chars),
    do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp consume_exponent_number!(<<char, rest::binary>>, chars) when char in [?+, ?-] do
    consume_exponent_number_digits!(rest, [char | chars])
  end

  defp consume_exponent_number!(<<char, rest::binary>>, chars) when char in ?0..?9 do
    consume_exponent_number_digits!(rest, [char | chars])
  end

  defp consume_exponent_number!(_rest, _chars) do
    raise ArgumentError, "invalid GraphQL numeric literal"
  end

  defp consume_exponent_number_digits!(<<char, rest::binary>>, chars) when char in ?0..?9 do
    consume_exponent_number_digits!(rest, [char | chars])
  end

  defp consume_exponent_number_digits!(rest, chars),
    do: {chars |> Enum.reverse() |> IO.iodata_to_binary(), rest}
end
