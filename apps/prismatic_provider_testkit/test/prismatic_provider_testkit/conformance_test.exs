defmodule PrismaticProviderTestkit.ConformanceTest do
  use ExUnit.Case, async: true

  alias PrismaticCodegen.ProviderIR
  alias PrismaticProviderTestkit.Conformance

  test "accepts a provider ir with provider metadata and operations" do
    ir = %ProviderIR{
      provider: %ProviderIR.Provider{
        name: "Example",
        namespace: ExampleSDK,
        base_url: "https://api.example.com/graphql"
      },
      operations: [
        %ProviderIR.Operation{
          id: "viewer",
          module: ExampleSDK.Operations.Viewer,
          operation: %{id: "viewer", name: "Viewer"}
        }
      ]
    }

    assert ^ir = Conformance.assert_provider_ir!(ir)
  end

  test "raises when operations are missing" do
    ir = %ProviderIR{
      provider: %ProviderIR.Provider{
        name: "Example",
        namespace: ExampleSDK,
        base_url: "https://api.example.com/graphql"
      }
    }

    assert_raise ArgumentError, "provider ir must include at least one operation", fn ->
      Conformance.assert_provider_ir!(ir)
    end
  end
end
