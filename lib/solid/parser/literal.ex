defmodule Solid.Parser.Literal do
  @moduledoc false
  import NimbleParsec

  @dialyzer :no_opaque

  def minus, do: string("-")
  def plus, do: string("+")

  def whitespace(opts) do
    utf8_string([?\s, ?\n, ?\r, ?\t], opts)
  end

  def int do
    minus()
    |> optional()
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})
  end

  def single_quoted_string do
    string(~s('))
    |> ignore()
    |> repeat(
      ascii_char([?'])
      |> lookahead_not()
      |> choice([string(~s(\')), utf8_char([])])
    )
    |> ignore(string(~s(')))
    |> reduce({List, :to_string, []})
  end

  def double_quoted_string do
    string(~s("))
    |> ignore()
    |> repeat(
      ascii_char([?"])
      |> lookahead_not()
      |> choice([string(~s(\")), utf8_char([])])
    )
    |> ignore(string(~s(")))
    |> reduce({List, :to_string, []})
  end

  def value do
    true_value =
      "true"
      |> string()
      |> replace(true)

    false_value =
      "false"
      |> string()
      |> replace(false)

    null =
      "nil"
      |> string()
      |> replace(nil)

    frac =
      "."
      |> string()
      |> concat(integer(min: 1))

    exp =
      [string("e"), string("E")]
      |> choice()
      |> optional(choice([plus(), minus()]))
      |> integer(min: 1)

    float =
      int()
      |> concat(frac)
      |> optional(exp)
      |> reduce({Enum, :join, [""]})
      |> map({String, :to_float, []})

    [
      float,
      int(),
      true_value,
      false_value,
      null,
      single_quoted_string(),
      double_quoted_string()
    ]
    |> choice()
    |> unwrap_and_tag(:value)
  end
end
