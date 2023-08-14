defmodule Solid.Tag.Case do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  def when_join(whens) do
    Enum.flat_map(whens, fn {:when, values} ->
      for {key, val} <- values, key == :value do
        {val, Keyword.get(values, :result)}
      end
    end)
  end

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    case_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("case"))
      |> ignore(space)
      |> concat(Argument.argument())
      |> ignore(BaseTag.closing_tag())

    when_condition =
      repeat(
        Argument.argument(),
        space |> ignore() |> ignore(choice([string(","), string("or")])) |> ignore(space) |> concat(Argument.argument())
      )

    when_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("when"))
      |> ignore(space)
      |> concat(when_condition)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)
      |> tag(:when)

    case_tag
    |> tag(:case_exp)
    # FIXME
    |> ignore(parsec({parser, :liquid_entry}))
    |> unwrap_and_tag(reduce(times(when_tag, min: 1), {__MODULE__, :when_join, []}), :whens)
    |> optional(tag(BaseTag.else_tag(parser), :else_exp))
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endcase"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([{:case_exp, field} | [{:whens, when_keyword} | _]] = tag, context, options) do
    {:ok, value, context} = Solid.Argument.get(field, context, options)

    result =
      case Enum.find(when_keyword, fn {keyfind, _} -> keyfind == value end) do
        {_, result} -> result
        _ -> nil
      end

    if result do
      {result, context}
    else
      {tag[:else_exp][:result], context}
    end
  end
end
