defmodule Solid.Tag.Tablerow do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal
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

    delimit = choice([space |> concat(string(~s(,))) |> concat(space), space])

    limit =
      "limit"
      |> string()
      |> ignore()
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(integer(min: 1), :limit)
      |> ignore(delimit)

    offset =
      "offset"
      |> string()
      |> ignore()
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(integer(min: 1), :offset)
      |> ignore(delimit)

    cols =
      "cols"
      |> string()
      |> ignore()
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(integer(min: 1), :cols)
      |> ignore(delimit)

    for_parameters =
      [limit, offset, cols]
      |> choice()
      |> repeat()
      |> reduce({Enum, :into, [%{}]})

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("tablerow"))
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
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endtablerow"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(
        [{:field, [enumerable_key]}, {:enumerable, enumerable}, {:parameters, parameters} | _] = exp,
        context,
        options
      ) do
    {:ok, enumerable, context} = enumerable(enumerable, context)

    enumerable = apply_parameters(enumerable, parameters)
    exp = Keyword.get(exp, :result)
    row_length = Enum.count(enumerable)

    {result, context} =
      for {cols, row_index} <- Enum.with_index(enumerable, 0), reduce: {[], context} do
        {acc_result, acc_context_initial} ->
          col_length = Enum.count(cols)

          {cols_result, cols_context} =
            for {col, col_index} <- Enum.with_index(cols, 0), reduce: {[], acc_context_initial} do
              {col_acc_result, col_acc_context_initial} ->
                col_acc_context =
                  acc_context_initial
                  |> set_enumerable_value(enumerable_key, col)
                  |> maybe_put_tablerow_map(
                    enumerable_key,
                    row_index,
                    col_index,
                    row_length,
                    col_length
                  )

                try do
                  {col_result, col_acc_context} = Solid.render(exp, col_acc_context, options)

                  col_acc_context =
                    restore_initial_forloop_value(col_acc_context, col_acc_context_initial)

                  {[
                     "<td class=\"col#{col_index + 1}\">#{col_result}</td>"
                     | col_acc_result
                   ], col_acc_context}
                catch
                  {:break_exp, result, context} ->
                    throw({:result, [result | acc_result], context})

                  {:continue_exp, result, context} ->
                    {[result | acc_result], context}
                end
            end

          cols_result = cols_result |> Enum.reverse() |> Enum.join()

          {[
             "<tr class=\"row#{row_index + 1}\">#{cols_result}</tr>"
             | acc_result
           ], cols_context}
      end

    result = result |> Enum.reverse() |> Enum.join()
    context = %{context | iteration_vars: Map.delete(context.iteration_vars, enumerable_key)}
    {[text: result], context}
  catch
    {:result, result, context} ->
      context = %{context | iteration_vars: Map.delete(context.iteration_vars, enumerable_key)}
      {[text: result], context}
  end

  defp set_enumerable_value(acc_context, key, value) do
    iteration_vars = Map.put(acc_context.iteration_vars, key, value)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp maybe_put_tablerow_map(acc_context, key, row_index, col_index, row_length, col_length) when key != "tablerow" do
    map = build_tablerow_map(row_index, col_index, row_length, col_length)
    iteration_vars = Map.put(acc_context.iteration_vars, "tablerow", map)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp build_tablerow_map(row_index, col_index, row_length, col_length) do
    %{
      "col" => col_index + 1,
      "col0" => col_index,
      "col_first" => col_index == 0,
      "col_last" => col_length == col_index + 1,
      "first" => row_index == 0,
      "index" => row_index,
      "index0" => row_index + 1,
      "last" => row_length == row_index + 1,
      "length" => row_length,
      "rindex" => row_length - row_index,
      "rindex0" => row_length - row_index - 1,
      "row" => row_index + 1
    }
  end

  defp restore_initial_forloop_value(acc_context, %{iteration_vars: %{"tablerow" => initial_forloop}}) do
    iteration_vars = Map.put(acc_context.iteration_vars, "tablerow", initial_forloop)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp restore_initial_forloop_value(acc_context, _) do
    acc_context
  end

  defp enumerable([range: [first: first, last: last]], context) do
    {_, first, context} = integer_or_field(first, context)
    {_, last, context} = integer_or_field(last, context)
    {:ok, first..last//1, context}
  end

  defp enumerable(field, context) do
    {:ok, value, context} = Solid.Argument.get(field, context)
    {:ok, value || [], context}
  end

  defp apply_parameters(enumerable, parameters) do
    enumerable
    |> offset(parameters)
    |> limit(parameters)
    |> cols(parameters)
  end

  defp offset(enumerable, %{offset: offset}) do
    Enum.slice(enumerable, offset..-1//1)
  end

  defp offset(enumerable, _), do: enumerable

  defp limit(enumerable, %{limit: limit}) do
    Enum.slice(enumerable, 0..(limit - 1)//1)
  end

  defp limit(enumerable, _), do: enumerable

  defp cols(enumerable, %{cols: cols}) do
    Enum.chunk_every(enumerable, cols)
  end

  defp cols(enumerable, _), do: [enumerable]

  defp integer_or_field(value, context) when is_integer(value), do: {:ok, value, context}
  defp integer_or_field(field, context), do: Solid.Argument.get([field], context)
end
