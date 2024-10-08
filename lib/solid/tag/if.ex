defmodule Solid.Tag.If do
  @moduledoc """
  If and Unless tags
  """

  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Expression
  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  space = Literal.whitespace(min: 0)

  operator =
    [
      string("=="),
      string("!="),
      string(">="),
      string("<="),
      string(">"),
      string("<"),
      string("contains")
    ]
    |> choice()
    |> map({:erlang, :binary_to_atom, [:utf8]})

  argument_filter =
    Argument.argument()
    |> tag(:argument)
    |> tag(
      repeat(
        [operator, string("and"), string("&&"), string("or"), string("||")]
        |> choice()
        |> lookahead_not()
        |> concat(Argument.filter())
      ),
      :filters
    )

  defcombinator(:__argument_filter__, argument_filter)

  boolean_operation =
    :__argument_filter__
    |> parsec()
    |> tag(:arg1)
    |> ignore(space)
    |> tag(operator, :op)
    |> ignore(space)
    |> tag(parsec(:__argument_filter__), :arg2)
    |> wrap()

  expression =
    space
    |> ignore()
    |> choice([boolean_operation, wrap(parsec(:__argument_filter__))])
    |> ignore(space)

  bool_and =
    [string("and"), string("&&")]
    |> choice()
    |> replace(:bool_and)

  bool_or =
    [string("or"), string("||")]
    |> choice()
    |> replace(:bool_or)

  boolean_expression =
    repeat(expression, [bool_and, bool_or] |> choice() |> concat(expression))

  defcombinator(:__boolean_expression__, boolean_expression)

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    if_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("if"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)

    elsif_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("elsif"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)
      |> tag(:elsif_exp)

    unless_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("unless"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(space)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)

    cond_if_tag =
      if_tag
      |> tag(:if_exp)
      |> tag(times(elsif_tag, min: 0), :elsif_exps)
      |> optional(tag(BaseTag.else_tag(parser), :else_exp))
      |> ignore(BaseTag.opening_tag())
      |> ignore(string("endif"))
      |> ignore(BaseTag.closing_tag())

    cond_unless_tag =
      unless_tag
      |> tag(:unless_exp)
      |> tag(times(elsif_tag, min: 0), :elsif_exps)
      |> optional(tag(BaseTag.else_tag(parser), :else_exp))
      |> ignore(BaseTag.opening_tag())
      |> ignore(string("endunless"))
      |> ignore(BaseTag.closing_tag())

    choice([cond_if_tag, cond_unless_tag])
  end

  @impl true
  def render([{:if_exp, exp} | _] = tag, context, options) do
    {result, context} = eval_expression(exp[:expression], context, options)
    if result, do: throw({:result, exp, context})

    context = eval_elsif_exps(tag[:elsif_exps], context, options)

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp, context})
    {nil, context}
  catch
    {:result, result, context} -> {result[:result], context}
  end

  def render([{:unless_exp, exp} | _] = tag, context, options) do
    {result, context} = eval_expression(exp[:expression], context, options)
    unless result, do: throw({:result, exp, context})

    context = eval_elsif_exps(tag[:elsif_exps], context, options)

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp, context})
    {nil, context}
  catch
    {:result, result, context} -> {result[:result], context}
  end

  defp eval_elsif_exps(nil, context, _options), do: context

  defp eval_elsif_exps(elsif_exps, context, options) do
    {result, context} = eval_elsifs(elsif_exps, context, options)
    if result, do: throw({:result, elem(result, 1), context})
    context
  end

  defp eval_elsifs(elsif_exps, context, options) do
    Enum.reduce_while(elsif_exps, {nil, context}, fn {:elsif_exp, elsif_exp}, {nil, context} ->
      {result, context} = eval_expression(elsif_exp[:expression], context, options)

      if result do
        {:halt, {{:elsif_exp, elsif_exp}, context}}
      else
        {:cont, {nil, context}}
      end
    end)
  end

  defp eval_expression(exps, context, options), do: Expression.eval(exps, context, options)
end
