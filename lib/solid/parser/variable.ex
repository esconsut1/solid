defmodule Solid.Parser.Variable do
  @moduledoc false
  import NimbleParsec

  alias Solid.Parser.Literal

  @dialyzer :no_opaque

  defp identifier, do: ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ??], min: 1)

  def bracket_access do
    string("[")
    |> ignore()
    |> choice([Literal.int(), Literal.single_quoted_string(), Literal.double_quoted_string()])
    |> ignore(string("]"))
  end

  def dot_access do
    string(".")
    |> ignore()
    |> concat(identifier())
  end

  def field do
    identifier()
    |> repeat(choice([dot_access(), bracket_access()]))
    |> tag(:field)
  end
end
