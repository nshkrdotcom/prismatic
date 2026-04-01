defmodule PrismaticCodegen.ProviderIR do
  @moduledoc """
  GraphQL-native intermediate representation for generated provider SDKs.
  """

  @type t :: %__MODULE__{
          provider: PrismaticCodegen.ProviderIR.Provider.t(),
          schema: map(),
          documents: [PrismaticCodegen.ProviderIR.Document.t()],
          operations: [PrismaticCodegen.ProviderIR.Operation.t()],
          models: [PrismaticCodegen.ProviderIR.Model.t()],
          enums: [PrismaticCodegen.ProviderIR.Enum.t()],
          artifact_plan: PrismaticCodegen.ProviderIR.ArtifactPlan.t() | nil
        }

  defstruct provider: nil,
            schema: %{},
            documents: [],
            operations: [],
            models: [],
            enums: [],
            artifact_plan: nil

  defmodule Provider do
    @moduledoc """
    Provider metadata embedded in the compiled IR.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            namespace: module(),
            client_module: module(),
            base_url: String.t(),
            auth: map(),
            output: %{lib_root: Path.t(), docs_root: Path.t()}
          }

    defstruct [:name, :namespace, :client_module, :base_url, auth: %{}, output: %{}]
  end

  defmodule Document do
    @moduledoc """
    Curated GraphQL document metadata.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            kind: :query | :mutation,
            path: Path.t(),
            relative_path: Path.t(),
            document: String.t(),
            root_field: String.t()
          }

    defstruct [:id, :name, :kind, :path, :relative_path, :document, :root_field]
  end

  defmodule Operation do
    @moduledoc """
    Operation entry compiled from a curated document and schema snapshot.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            module: module(),
            operation: Prismatic.Operation.t(),
            document: PrismaticCodegen.ProviderIR.Document.t(),
            response_type: String.t(),
            model_module: module() | nil
          }

    defstruct [:id, :name, :module, :operation, :document, :response_type, :model_module]
  end

  defmodule Model do
    @moduledoc """
    Generated model definition derived from an operation response type.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            module: module(),
            fields: [PrismaticCodegen.ProviderIR.Model.Field.t()]
          }

    defstruct [:name, :module, fields: []]

    defmodule Field do
      @moduledoc """
      Field metadata for a generated model definition.
      """

      @type t :: %__MODULE__{
              name: String.t(),
              key: atom(),
              kind: String.t(),
              type_name: String.t()
            }

      defstruct [:name, :key, :kind, :type_name]
    end
  end

  defmodule Enum do
    @moduledoc """
    Generated enum definition referenced by one or more models.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            module: module(),
            values: [String.t()]
          }

    defstruct [:name, :module, values: []]
  end

  defmodule ArtifactPlan do
    @moduledoc """
    The full generated artifact inventory for a provider build.
    """

    @type t :: %__MODULE__{
            files: [Path.t()]
          }

    defstruct files: []
  end
end
