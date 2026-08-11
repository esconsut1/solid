defmodule Solid.Tag.For do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Forloop
  alias Solid.LoopSlice
  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal
  alias Solid.Parser.LoopParameters
  alias Solid.Parser.Variable

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    range =
      "("
      |> string()
      |> ignore()
      |> unwrap_and_tag(choice([integer(min: 1), Variable.field()]), :first)
      |> ignore(string(".."))
      |> unwrap_and_tag(choice([integer(min: 1), Variable.field()]), :last)
      |> ignore(string(")"))
      |> tag(:range)

    delimit = LoopParameters.delimit()

    sort_by =
      "sort_by"
      |> string()
      |> ignore()
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(Variable.field(), :sort_by)
      |> ignore(delimit)

    order =
      "order"
      |> string()
      |> ignore()
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(
        choice([
          "descending" |> string() |> replace(:desc),
          "ascending" |> string() |> replace(:asc),
          "desc" |> string() |> replace(:desc),
          "asc" |> string() |> replace(:asc)
        ]),
        :order
      )
      |> ignore(delimit)

    reversed =
      "reversed"
      |> string()
      |> replace({:reversed, 0})
      |> ignore(delimit)

    for_parameters =
      LoopParameters.reduce_parameters([
        LoopParameters.limit(),
        LoopParameters.offset(),
        sort_by,
        order,
        reversed
      ])

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("for"))
    |> ignore(space)
    |> concat(Argument.argument())
    |> ignore(space)
    |> ignore(string("in"))
    |> ignore(space)
    |> tag(choice([Variable.field(), range]), :enumerable)
    |> ignore(delimit)
    |> unwrap_and_tag(for_parameters, :parameters)
    |> ignore(BaseTag.closing_tag())
    |> tag(parsec({parser, :liquid_entry}), :result)
    |> optional(tag(BaseTag.else_tag(parser), :else_exp))
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endfor"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(
        [{:field, [enumerable_key]}, {:enumerable, enumerable_ast}, {:parameters, parameters} | _] = exp,
        context,
        options
      ) do
    {:ok, enumerable, context} = evaluate_enumerable(enumerable_ast, context)
    loop_name = LoopSlice.loop_name(enumerable_key, enumerable_ast)

    {enumerable, context} =
      LoopSlice.apply(enumerable, Map.take(parameters, [:limit, :offset]), context, loop_name)

    enumerable =
      enumerable
      |> sort_by(parameters)
      |> reversed(parameters)

    do_for(enumerable_key, enumerable, exp, context, options)
  end

  defp do_for(_, [], exp, context, _options) do
    exp = Keyword.get(exp, :else_exp)
    {exp[:result], context}
  end

  defp do_for(enumerable_key, enumerable, exp, context, options) do
    exp = Keyword.get(exp, :result)
    length = Enum.count(enumerable)

    {result, context} =
      for {v, index} <- Enum.with_index(enumerable, 0), reduce: {[], context} do
        {acc_result, acc_context_initial} ->
          acc_context =
            acc_context_initial
            |> set_enumerable_value(enumerable_key, v)
            |> maybe_put_forloop_map(enumerable_key, index, length)

          try do
            {result, acc_context} = Solid.render(exp, acc_context, options)
            acc_context = restore_forloop(acc_context, acc_context_initial)
            {[result | acc_result], acc_context}
          catch
            {:break_exp, result, context} ->
              context = restore_forloop(context, acc_context_initial)
              throw({:result, [result | acc_result], context})

            {:continue_exp, result, context} ->
              context = restore_forloop(context, acc_context_initial)
              {[result | acc_result], context}
          end
      end

    context = cleanup_for_loop(context, enumerable_key)
    {[text: Enum.reverse(result)], context}
  catch
    {:result, result, context} ->
      context = cleanup_for_loop(context, enumerable_key)
      {[text: Enum.reverse(result)], context}
  end

  defp set_enumerable_value(acc_context, key, value) do
    iteration_vars = Map.put(acc_context.iteration_vars, key, value)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp maybe_put_forloop_map(acc_context, key, index, loop_length) when key != "forloop" do
    parentloop = Map.get(acc_context.iteration_vars, "forloop")
    map = Forloop.build(index, loop_length, parentloop)
    iteration_vars = Map.put(acc_context.iteration_vars, "forloop", map)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp maybe_put_forloop_map(acc_context, _key, _index, _loop_length) do
    acc_context
  end

  defp restore_forloop(acc_context, %{iteration_vars: %{"forloop" => initial_forloop}}) do
    iteration_vars = Map.put(acc_context.iteration_vars, "forloop", initial_forloop)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp restore_forloop(acc_context, _) do
    iteration_vars = Map.delete(acc_context.iteration_vars, "forloop")
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp cleanup_for_loop(context, enumerable_key) do
    %{context | iteration_vars: Map.delete(context.iteration_vars, enumerable_key)}
  end

  defp evaluate_enumerable([range: [first: first, last: last]], context) do
    {_, first, context} = integer_or_field(first, context)
    {_, last, context} = integer_or_field(last, context)
    {:ok, Enum.to_list(first..last//1), context}
  end

  defp evaluate_enumerable(field, context) do
    {:ok, value, context} = Solid.Argument.get(field, context)
    {:ok, Solid.Utils.enumerable_to_list(value || []), context}
  end

  defp sort_by([%{} | _] = enumerable, %{sort_by: {:field, fields}, order: order_by}) do
    if Enum.any?(fields, &(&1 in ~w(index index0 rindex rindex0 first last length parentloop))) do
      Enum.sort(enumerable, order_by)
    else
      Enum.sort_by(
        enumerable,
        &(Enum.reduce(fields, &1, fn field, acc -> Map.get(acc, field) end) || &1),
        order_by
      )
    end
  end

  defp sort_by(enumerable, %{sort_by: {:field, _fields}, order: order_by}) do
    Enum.sort(enumerable, order_by)
  end

  defp sort_by(enumerable, %{sort_by: {:field, _fields}} = parameters) do
    sort_by(enumerable, Map.put(parameters, :order, :asc))
  end

  defp sort_by(enumerable, _), do: enumerable

  defp reversed(enumerable, %{reversed: _}) do
    Enum.reverse(enumerable)
  end

  defp reversed(enumerable, _), do: enumerable

  defp integer_or_field(value, context) when is_integer(value), do: {:ok, value, context}
  defp integer_or_field(field, context), do: Solid.Argument.get([field], context)
end
