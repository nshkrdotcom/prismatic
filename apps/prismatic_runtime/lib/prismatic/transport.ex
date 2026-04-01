defmodule Prismatic.Transport do
  @moduledoc false

  @type response :: %{
          required(:status) => pos_integer(),
          required(:headers) => list(),
          required(:body) => map()
        }

  @callback execute(Prismatic.Context.t(), map(), keyword()) ::
              {:ok, response()} | {:error, term()}
end
