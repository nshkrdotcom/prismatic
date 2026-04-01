defmodule Mix.Tasks.Prismatic.Codegen.Verify do
  use Mix.Task

  @moduledoc false
  @shortdoc "Verifies that generated provider artifacts are current"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    provider = PrismaticCodegen.CLI.provider_from_args!(args)
    :ok = PrismaticCodegen.Verify.assert_current!(provider)

    Mix.shell().info("generated artifacts are current for #{provider.name}")
  end
end
