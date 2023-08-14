defmodule Solid.Tag.Capture do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal
  alias Solid.Parser.Variable

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("capture"))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(BaseTag.closing_tag())
    |> tag(parsec({parser, :liquid_entry}), :result)
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endcapture"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([field: [field_name], result: result], context, options) do
    {captured, context} = Solid.render(result, context, options)

    {[], %{context | vars: Map.put(context.vars, field_name, IO.iodata_to_binary(captured))}}
  end

  def render([field: fields_name, result: result], context, options) do
    {captured, context} = Solid.render(result, context, options)

    fields = for field <- fields_name, do: Access.key(field, %{})
    context_vars = put_in(context.vars, fields, IO.iodata_to_binary(captured))

    {[], %{context | vars: context_vars}}
  end
end
