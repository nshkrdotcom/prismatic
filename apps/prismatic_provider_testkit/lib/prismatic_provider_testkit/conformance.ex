defmodule PrismaticProviderTestkit.Conformance do
  @moduledoc """
  Conformance checks for compiled provider IR.
  """

  alias PrismaticCodegen.ProviderIR

  @spec assert_provider_ir!(ProviderIR.t()) :: ProviderIR.t()
  def assert_provider_ir!(%ProviderIR{provider: provider, operations: operations} = ir) do
    if is_nil(provider) do
      raise ArgumentError, "provider ir must include provider metadata"
    end

    if operations == [] do
      raise ArgumentError, "provider ir must include at least one operation"
    end

    ir
  end
end
