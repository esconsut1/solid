defmodule Solid.Tag.Counter do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal
  alias Solid.Parser.Variable

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    increment =
      "increment"
      |> string()
      |> replace({1, 0})

    decrement =
      "decrement"
      |> string()
      |> replace({-1, -1})

    BaseTag.opening_tag()
    |> ignore()
    |> concat(choice([increment, decrement]))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([{operation, default}, field], context, options) do
    {:ok, value, context} = Argument.get([field], context, [{:scopes, [:counter_vars]} | options])
    value = value || default

    {:field, [field_name]} = field

    context = %{
      context
      | counter_vars: Map.put(context.counter_vars, field_name, value + operation)
    }

    {[text: to_string(value)], context}
  end
end
