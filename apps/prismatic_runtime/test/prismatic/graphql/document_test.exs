defmodule Prismatic.GraphQL.DocumentTest do
  use ExUnit.Case, async: true

  alias Prismatic.GraphQL.Document

  test "selects a named query operation" do
    assert %{kind: :query, name: "Viewer"} =
             Document.select_operation!("query Viewer { viewer { id } }")
  end

  test "selects an anonymous query operation" do
    assert %{kind: :query, name: nil} =
             Document.select_operation!("{ viewer { id } }")
  end

  test "skips fragments and handles default values before the operation selection set" do
    document = """
    fragment IssueFields on Issue {
      id
      title
    }

    query ViewerIssues($limit: Int = 10, $filters: IssueFilter = {priority: {gte: 2}}) {
      viewer {
        assignedIssues(first: $limit, filter: $filters) {
          nodes {
            ...IssueFields
          }
        }
      }
    }
    """

    assert %{kind: :query, name: "ViewerIssues"} = Document.select_operation!(document)
  end

  test "requires operation_name when the document declares multiple operations" do
    document = """
    query Viewer { viewer { id } }
    mutation UpdateViewer { viewerUpdate(input: {name: "Ada"}) { success } }
    """

    error = assert_raise ArgumentError, fn -> Document.select_operation!(document) end

    assert error.message ==
             "document declares multiple operations; pass operation_name: \"...\" to select one"
  end

  test "selects the requested operation from a multi-operation document" do
    document = """
    query Viewer { viewer { id } }
    mutation UpdateViewer { viewerUpdate(input: {name: "Ada"}) { success } }
    """

    assert %{kind: :mutation, name: "UpdateViewer"} =
             Document.select_operation!(document, "UpdateViewer")
  end

  test "rejects blank operation_name" do
    assert_raise ArgumentError, "operation_name must not be blank", fn ->
      Document.select_operation!("query Viewer { viewer { id } }", "   ")
    end
  end
end
