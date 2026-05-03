defmodule PrismaticCodegen.ProviderIR do
  @moduledoc """
  GraphQL-native intermediate representation for generated provider SDKs.
  """

  @type t :: %__MODULE__{
          provider: PrismaticCodegen.ProviderIR.Provider.t(),
          schema: PrismaticCodegen.ProviderIR.Schema.t(),
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
            public_namespace: module(),
            client_module: module(),
            base_url: String.t(),
            auth: map(),
            source: %{introspection_path: Path.t(), schema_sdl_path: Path.t()},
            output: %{lib_root: Path.t(), docs_root: Path.t()}
          }

    defstruct [
      :name,
      :namespace,
      :public_namespace,
      :client_module,
      :base_url,
      auth: %{},
      source: %{},
      output: %{}
    ]
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
              key: String.t(),
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

  defmodule Schema do
    @moduledoc """
    Full schema metadata compiled from the introspection snapshot.
    """

    @type t :: %__MODULE__{
            query_type_name: String.t(),
            mutation_type_name: String.t() | nil,
            subscription_type_name: String.t() | nil,
            types: [PrismaticCodegen.ProviderIR.Schema.Type.t()]
          }

    defstruct [:query_type_name, :mutation_type_name, :subscription_type_name, types: []]

    defmodule Type do
      @moduledoc """
      Schema type entry.
      """

      @type t :: %__MODULE__{
              kind: String.t(),
              name: String.t(),
              description: String.t() | nil,
              fields: [PrismaticCodegen.ProviderIR.Schema.Field.t()],
              input_fields: [PrismaticCodegen.ProviderIR.Schema.InputValue.t()],
              interfaces: [PrismaticCodegen.ProviderIR.Schema.TypeRef.t()],
              enum_values: [PrismaticCodegen.ProviderIR.Schema.EnumValue.t()],
              possible_types: [PrismaticCodegen.ProviderIR.Schema.TypeRef.t()],
              specified_by_url: String.t() | nil
            }

      defstruct [
        :kind,
        :name,
        :description,
        :specified_by_url,
        fields: [],
        input_fields: [],
        interfaces: [],
        enum_values: [],
        possible_types: []
      ]
    end

    defmodule Field do
      @moduledoc """
      Field metadata for object and interface types.
      """

      @type t :: %__MODULE__{
              name: String.t(),
              description: String.t() | nil,
              args: [PrismaticCodegen.ProviderIR.Schema.InputValue.t()],
              type: PrismaticCodegen.ProviderIR.Schema.TypeRef.t(),
              is_deprecated: boolean(),
              deprecation_reason: String.t() | nil
            }

      defstruct [:name, :description, :type, :is_deprecated, :deprecation_reason, args: []]
    end

    defmodule InputValue do
      @moduledoc """
      Argument or input-field metadata.
      """

      @type t :: %__MODULE__{
              name: String.t(),
              description: String.t() | nil,
              type: PrismaticCodegen.ProviderIR.Schema.TypeRef.t(),
              default_value: String.t() | nil,
              is_deprecated: boolean(),
              deprecation_reason: String.t() | nil
            }

      defstruct [
        :name,
        :description,
        :type,
        :default_value,
        :is_deprecated,
        :deprecation_reason
      ]
    end

    defmodule EnumValue do
      @moduledoc """
      Enum-value metadata.
      """

      @type t :: %__MODULE__{
              name: String.t(),
              description: String.t() | nil,
              is_deprecated: boolean(),
              deprecation_reason: String.t() | nil
            }

      defstruct [:name, :description, :is_deprecated, :deprecation_reason]
    end

    defmodule TypeRef do
      @moduledoc """
      Recursive GraphQL type reference.
      """

      @type t :: %__MODULE__{
              kind: String.t(),
              name: String.t() | nil,
              of_type: t() | nil
            }

      defstruct [:kind, :name, :of_type]
    end
  end
end
