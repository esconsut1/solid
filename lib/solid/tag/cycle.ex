defmodule Solid.Tag.Cycle do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)
    quoted = choice([Literal.double_quoted_string(), Literal.single_quoted_string()])

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("cycle"))
    |> ignore(space)
    |> optional(
      quoted
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(:name)
    )
    |> concat(
      quoted
      |> repeat(
        space
        |> ignore()
        |> ignore(string(","))
        |> ignore(space)
        |> concat(quoted)
      )
      |> tag(:values)
    )
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(cycle, context, _options) do
    {context, result} = Solid.Context.run_cycle(context, cycle)

    {[text: result], context}
  end
end
