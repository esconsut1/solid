defmodule Solid.Parser.LoopParameters do
  @moduledoc false
  import NimbleParsec

  alias Solid.Parser.Literal
  alias Solid.Parser.Variable

  defp space, do: Literal.whitespace(min: 0)

  def delimit do
    choice([space() |> concat(string(",")) |> concat(space()), space()])
  end

  def limit do
    "limit"
    |> string()
    |> ignore()
    |> ignore(space())
    |> ignore(string(":"))
    |> ignore(space())
    |> unwrap_and_tag(limit_value(), :limit)
    |> ignore(delimit())
  end

  def offset do
    "offset"
    |> string()
    |> ignore()
    |> ignore(space())
    |> ignore(string(":"))
    |> ignore(space())
    |> unwrap_and_tag(offset_value(), :offset)
    |> ignore(delimit())
  end

  defp limit_value do
    choice([integer(min: 1), Variable.field()])
  end

  defp offset_value do
    choice([
      "continue" |> string() |> replace({:continue, 0}),
      integer(min: 1),
      Variable.field()
    ])
  end

  def reduce_parameters(parameters) do
    parameters
    |> choice()
    |> repeat()
    |> reduce({Enum, :into, [%{}]})
  end
end
