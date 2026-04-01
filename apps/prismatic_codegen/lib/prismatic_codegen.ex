defmodule PrismaticCodegen do
  @moduledoc """
  Public entrypoint for Prismatic code generation.
  """

  alias PrismaticCodegen.Compiler
  alias PrismaticCodegen.Provider
  alias PrismaticCodegen.ProviderIR

  @spec compile(Provider.t()) :: {:ok, ProviderIR.t()} | {:error, term()}
  defdelegate compile(provider), to: Compiler

  @spec compile!(Provider.t()) :: ProviderIR.t()
  defdelegate compile!(provider), to: Compiler

  @spec render!(Provider.t() | module() | String.t()) :: [PrismaticCodegen.RenderedFile.t()]
  defdelegate render!(provider), to: Compiler

  @spec generate!(Provider.t() | module() | String.t()) :: :ok
  defdelegate generate!(provider), to: Compiler
end
