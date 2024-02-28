defmodule Solid.Parser.Variable do
  @moduledoc false
  import NimbleParsec

  alias Solid.Parser.Literal

  @dialyzer :no_opaque

  defp identifier, do: ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ??], min: 1)

  def bracket_access do
    true_value =
      "true"
      |> string()
      |> replace(true)

    false_value =
      "false"
      |> string()
      |> replace(false)

    null =
      [string("nil"), string("null")]
      |> choice()
      |> replace(nil)

    frac =
      "."
      |> string()
      |> concat(integer(min: 1))

    exp =
      [string("e"), string("E")]
      |> choice()
      |> optional(choice([Literal.plus(), Literal.minus()]))
      |> integer(min: 1)

    float =
      Literal.int()
      |> concat(frac)
      |> optional(exp)
      |> reduce({Enum, :join, [""]})
      |> map({String, :to_float, []})

    "["
    |> string()
    |> ignore()
    |> choice([
      float,
      Literal.int(),
      true_value,
      false_value,
      null,
      Literal.single_quoted_string(),
      Literal.double_quoted_string(),
      tag(identifier(), :field)
    ])
    |> ignore(string("]"))
  end

  def dot_access do
    "."
    |> string()
    |> ignore()
    |> concat(identifier())
  end

  def field do
    identifier()
    |> repeat(choice([dot_access(), bracket_access()]))
    |> tag(:field)
  end
end
