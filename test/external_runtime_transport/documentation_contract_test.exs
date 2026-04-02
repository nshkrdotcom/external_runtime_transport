defmodule ExternalRuntimeTransport.DocumentationContractTest do
  use ExUnit.Case, async: true

  test "hexdocs navigation includes every guide and examples readme" do
    extras =
      Mix.Project.config()
      |> Keyword.fetch!(:docs)
      |> Keyword.fetch!(:extras)
      |> Enum.map(&extra_path/1)
      |> MapSet.new()

    expected =
      ["examples/README.md" | Path.wildcard("guides/*.md")]
      |> Enum.map(&to_string/1)
      |> MapSet.new()

    assert MapSet.subset?(expected, extras),
           "missing HexDocs extras: #{inspect(MapSet.to_list(MapSet.difference(expected, extras)))}"
  end

  defp extra_path({path, _opts}) when is_atom(path), do: Atom.to_string(path)
  defp extra_path({path, _opts}) when is_binary(path), do: path
  defp extra_path(path) when is_atom(path), do: Atom.to_string(path)
  defp extra_path(path) when is_binary(path), do: path
end
