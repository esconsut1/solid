defmodule Solid.Tag.Echo do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("echo"))
    |> ignore(space)
    |> tag(Argument.argument(), :argument)
    |> optional(tag(repeat(Argument.filter()), :filters))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([argument: argument, filters: filters], context, options) do
    {:ok, value, context} =
      Solid.Argument.get(argument, context, [{:filters, filters} | options])

    {[text: value], context}
  end
end
