defmodule Prismatic.Response do
  @moduledoc """
  Successful GraphQL response wrapper.
  """

  @type t :: %__MODULE__{
          status: pos_integer(),
          data: map() | nil,
          errors: list(),
          extensions: map() | nil,
          headers: [{String.t(), String.t()}],
          request_id: String.t() | nil
        }

  defstruct status: 200,
            data: nil,
            errors: [],
            extensions: nil,
            headers: [],
            request_id: nil
end
