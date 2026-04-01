defmodule Prismatic do
  @moduledoc """
  Public entrypoint for the Prismatic runtime.
  """

  alias Prismatic.Client
  alias Prismatic.Operation

  @spec new_client(keyword()) :: Client.t()
  defdelegate new_client(opts), to: Client, as: :new!

  @spec execute_operation(Client.t(), Operation.t(), map(), keyword()) ::
          {:ok, Prismatic.Response.t()} | {:error, Prismatic.Error.t()}
  defdelegate execute_operation(client, operation, variables \\ %{}, opts \\ []), to: Client

  @spec execute_document(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Prismatic.Response.t()} | {:error, Prismatic.Error.t()}
  defdelegate execute_document(client, document, variables \\ %{}, opts \\ []), to: Client
end
