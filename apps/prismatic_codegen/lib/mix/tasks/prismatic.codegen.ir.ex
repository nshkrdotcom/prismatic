defmodule Mix.Tasks.Prismatic.Codegen.Ir do
  use Mix.Task

  @moduledoc false
  @shortdoc "Compiles a provider definition and prints the provider IR"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    provider = PrismaticCodegen.CLI.provider_from_args!(args)
    ir = PrismaticCodegen.compile!(provider)

    IO.puts(inspect(ir, pretty: true, limit: :infinity))
  end
end
