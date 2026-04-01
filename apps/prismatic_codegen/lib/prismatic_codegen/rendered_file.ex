defmodule PrismaticCodegen.RenderedFile do
  @moduledoc """
  Rendered artifact emitted by a codegen renderer before it is written to disk.
  """

  @type t :: %__MODULE__{
          path: Path.t(),
          kind: atom(),
          content: binary()
        }

  defstruct [:path, :kind, :content]
end
