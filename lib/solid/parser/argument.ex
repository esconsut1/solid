defmodule Solid.Parser.Argument do
  @moduledoc false
  import NimbleParsec

  alias Solid.Parser.Literal
  alias Solid.Parser.Variable

  @dialyzer :no_opaque

  defp space, do: Literal.whitespace(min: 0)
  defp identifier, do: ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ??], min: 1)

  def argument_name do
    identifier()
    |> concat(ascii_string([?a..?z, ?A..?Z, ?_], min: 0))
    |> reduce({Enum, :join, []})
  end

  def argument, do: choice([Literal.value(), Variable.field()])

  def named_argument do
    argument_name()
    |> ignore(space())
    |> ignore(string(":"))
    |> ignore(space())
    |> choice([Literal.value(), Variable.field()])
  end

  def positional_arguments do
    repeat(argument(), space() |> ignore() |> ignore(string(",")) |> ignore(space()) |> concat(argument()))
  end

  def named_arguments do
    named_argument()
    |> repeat(
      space()
      |> ignore()
      |> ignore(string(","))
      |> ignore(space())
      |> concat(named_argument())
    )
    |> tag(:named_arguments)
  end

  def with_parameter do
    "with"
    |> string()
    |> ignore()
    |> ignore(space())
    |> concat(Variable.field())
    |> ignore(space())
    |> ignore(string("as"))
    |> ignore(space())
    |> concat(argument_name())
    |> tag(:with_parameter)
  end

  def filter do
    filter_name =
      [?a..?z, ?A..?Z]
      |> ascii_string(1)
      |> concat(ascii_string([?a..?z, ?A..?Z, ?_, ?0..?9], min: 0))
      |> reduce({Enum, :join, []})

    space()
    |> ignore()
    |> ignore(string("|"))
    |> ignore(space())
    |> concat(filter_name)
    |> tag(
      optional(space() |> ignore() |> ignore(string(":")) |> ignore(space()) |> concat(arguments())),
      :arguments
    )
    |> tag(:filter)
  end

  def arguments, do: choice([named_arguments(), positional_arguments()])
end
