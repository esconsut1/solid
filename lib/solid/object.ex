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

  defp apply_lazy(fun) when is_function(fun, 0), do: fun.()
  defp apply_lazy(value), do: value

  defp stringify!(value) when is_list(value) do
    value
    |> List.flatten()
    |> Enum.map(&stringify!/1)
    |> Enum.join()
  end

  defp stringify!(value) when is_tuple(value) do
    Tuple.to_list(value) |> stringify!()
  end

  defp stringify!(value) when is_map(value) and not is_struct(value) do
    "#{inspect(value)}"
  end

  defp stringify!(value), do: to_string(value)
end
