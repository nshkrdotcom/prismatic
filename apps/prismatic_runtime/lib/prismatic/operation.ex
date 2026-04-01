defmodule Prismatic.Operation do
  @moduledoc """
  GraphQL operation metadata used by provider SDKs and the runtime.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          kind: :query | :mutation,
          document: String.t(),
          root_field: String.t() | nil,
          description: String.t() | nil
        }

  @enforce_keys [:id, :name, :kind, :document]
  defstruct [:id, :name, :kind, :document, :root_field, :description]

  @spec new!(keyword()) :: t()
  def new!(opts) do
    kind = Keyword.fetch!(opts, :kind)

    unless kind in [:query, :mutation] do
      raise ArgumentError, "operation kind must be :query or :mutation"
    end

    struct!(__MODULE__, opts)
  end
end
