defmodule PrismaticCodegen.CLI do
  @moduledoc false

  @spec provider_from_args!([String.t()]) :: PrismaticCodegen.Provider.t()
  def provider_from_args!(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, strict: [provider: :string])

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    provider =
      opts
      |> Keyword.get(:provider)
      |> case do
        nil -> Mix.raise("missing required --provider Module.Name option")
        value -> value
      end

    PrismaticCodegen.Provider.load!(provider)
  end
end
