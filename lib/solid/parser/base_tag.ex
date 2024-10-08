defmodule Solid.Parser.BaseTag do
  @moduledoc false
  import NimbleParsec

  defp space, do: Solid.Parser.Literal.whitespace(min: 0)

  def opening_tag do
    "{%"
    |> string()
    |> concat(optional(string("-")))
    |> concat(space())
  end

  def comment_tag do
    "{%"
    |> string()
    |> ignore(space())
    |> concat(string("#"))
    |> concat(space())
  end

  def closing_tag do
    closing_wc_tag = string("-%}")

    closing_wc_tag_and_whitespace =
      closing_wc_tag
      |> concat(space())
      |> ignore()

    concat(space(), choice([closing_wc_tag_and_whitespace, string("%}")]))
  end

  def else_tag(parser) do
    opening_tag()
    |> ignore()
    |> ignore(string("else"))
    |> ignore(closing_tag())
    |> tag(parsec({parser, :liquid_entry}), :result)
  end
end
