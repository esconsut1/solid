defmodule Solid.LoopSlice do
  @moduledoc false

  alias Solid.Context

  @spec apply(list() | Enumerable.t(), map(), Context.t(), String.t()) ::
          {list(), Context.t()}
  def apply(enumerable, parameters, context, loop_name) do
    enumerable = Solid.Utils.enumerable_to_list(enumerable)
    {from, context} = resolve_offset(Map.get(parameters, :offset), loop_name, context)
    to = resolve_limit(Map.get(parameters, :limit), from, context)
    segment = slice(enumerable, from, to)
    context = put_register(context, loop_name, from + length(segment))
    {segment, context}
  end

  defp resolve_offset({:continue, 0}, loop_name, context) do
    {Map.get(context.for_registers, loop_name, 0), context}
  end

  defp resolve_offset({:field, _} = field, _loop_name, context) do
    {:ok, value, context} = Solid.Argument.get([field], context)
    {to_integer(value), context}
  end

  defp resolve_offset(offset, _loop_name, context) when is_integer(offset) do
    {offset, context}
  end

  defp resolve_offset(nil, _loop_name, context), do: {0, context}

  defp resolve_limit({:field, _} = field, from, context) do
    {:ok, value, _context} = Solid.Argument.get([field], context)
    from + to_integer(value)
  end

  defp resolve_limit(limit, from, _context) when is_integer(limit) do
    from + limit
  end

  defp resolve_limit(nil, _from, _context), do: nil

  defp slice(enumerable, from, nil) do
    Enum.drop(enumerable, from)
  end

  defp slice(_enumerable, from, to) when to <= from, do: []

  defp slice(enumerable, from, to) do
    Enum.slice(enumerable, from..(to - 1))
  end

  defp put_register(context, loop_name, offset) do
    %{context | for_registers: Map.put(context.for_registers, loop_name, offset)}
  end

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_float(value), do: trunc(value)

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 0
    end
  end

  defp to_integer(_), do: 0

  def loop_name(variable_name, range: [first: first, last: last]) do
    first_str = range_part(first)
    last_str = range_part(last)
    "#{variable_name}-(#{first_str}..#{last_str})"
  end

  def loop_name(variable_name, field: fields) do
    "#{variable_name}-#{Enum.join(fields, ".")}"
  end

  def loop_name(variable_name, {:field, fields}) do
    "#{variable_name}-#{Enum.join(fields, ".")}"
  end

  defp range_part(value) when is_integer(value), do: Integer.to_string(value)
  defp range_part({:field, fields}), do: Enum.join(fields, ".")
  defp range_part({:value, value}), do: to_string(value)
end
