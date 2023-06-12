defmodule Solid.Object do
  @moduledoc """
  Liquid objects are arguments with filter(s) applied to them
  """
  alias Solid.{Argument, Context}

  @spec render(Keyword.t(), Context.t(), Keyword.t()) :: {:ok, String.t(), Context.t()}
  def render([], context, _options), do: {:ok, [], context}

  def render(object, context, options) when is_list(object) do
    argument = object[:argument]

    {:ok, value, context} =
      Argument.get(argument, context, [filters: object[:filters]] ++ options)

    value = apply_lazy(value) |> stringify!()

    {:ok, value, context}
  end

  defp apply_lazy(fun) when is_function(fun, 0) do
    task = Task.async(fun)
    timeout = :timer.minutes(3)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> nil
    end
  end

  defp apply_lazy(value), do: value

  defp stringify!(value) when is_list(value) do
    for v <- List.flatten(value), into: "", do: stringify!(v)
  end

  defp stringify!(value) when is_tuple(value) do
    Tuple.to_list(value) |> stringify!()
  end

  defp stringify!(value) when is_map(value) and not is_struct(value) do
    "#{inspect(value)}"
  end

  defp stringify!(value), do: to_string(value)
end
