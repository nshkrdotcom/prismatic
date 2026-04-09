defmodule Prismatic.Transport.Req do
  @moduledoc false

  @behaviour Prismatic.Transport

  alias Prismatic.Transport.Pristine, as: PristineTransport

  @impl true
  def execute(context, payload, opts), do: PristineTransport.execute(context, payload, opts)
end
