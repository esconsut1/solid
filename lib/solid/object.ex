defmodule Solid.Object do
  @moduledoc """
  Liquid objects are arguments with filter(s) applied to them
  """
  alias Solid.Argument
  alias Solid.Context

  @spec render(Keyword.t(), Context.t(), Keyword.t()) :: {:ok, String.t(), Context.t()}
  def render([], context, _options), do: {:ok, [], context}

  def render(object, context, options) when is_list(object) do
    argument = object[:argument]

    {:ok, value, context} = Argument.get(argument, context, [filters: object[:filters]] ++ options)

    value = value |> Solid.Utils.apply_lazy() |> stringify!()

    {:ok, value, context}
  end

  defp stringify!(value) when is_list(value) do
    for v <- List.flatten(value), into: "", do: stringify!(v)
  end

  defp stringify!(value) when is_tuple(value) do
    value |> Tuple.to_list() |> stringify!()
  end

  defp stringify!(value) when is_map(value) and not is_struct(value) do
    "#{inspect(value)}"
  end

  defp stringify!(value), do: to_string(value)
end
