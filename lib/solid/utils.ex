defmodule Solid.Utils do
  @moduledoc false

  # Previously this ran in a supervised Task with a timeout and returned
  # `nil` on timeout/errors. Spawning a process for every lazy value is
  # expensive in template hot paths, so we evaluate inline while keeping
  # the same "don't crash rendering" semantics.
  def apply_lazy(fun) when is_function(fun, 0) do
    fun.()
  rescue
    _ -> nil
  catch
    _kind, _reason -> nil
  end

  def apply_lazy(value), do: value

  def enumerable_to_list(list) when is_list(list), do: list
  def enumerable_to_list(%Range{} = range), do: Enum.to_list(range)
  def enumerable_to_list(nil), do: []

  def enumerable_to_list(map) when is_map(map) and not is_struct(map) do
    Map.to_list(map)
  end

  def enumerable_to_list(value), do: List.wrap(value)
end
