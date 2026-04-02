defmodule Prismatic.Error do
  @moduledoc """
  Normalized Prismatic runtime error.
  """

  defexception [:type, :message, :status, :graphql_errors, :request_id, :details]

  @type t :: %__MODULE__{
          type: :auth | :transport | :http | :graphql,
          message: String.t(),
          status: pos_integer() | nil,
          graphql_errors: list() | nil,
          request_id: String.t() | nil,
          details: map()
        }

  @impl true
  def exception(fields) do
    struct!(__MODULE__, fields)
  end
end
