defmodule Mix.Tasks.Prismatic.Codegen.Generate do
  use Mix.Task

  @moduledoc false
  @shortdoc "Generates provider SDK artifacts from a provider definition"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    provider = PrismaticCodegen.CLI.provider_from_args!(args)
    :ok = PrismaticCodegen.generate!(provider)

    Mix.shell().info("generated artifacts for #{provider.name}")
  end
end
