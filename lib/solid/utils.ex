defmodule Solid.Utils do
  @moduledoc false

  def apply_lazy(fun) when is_function(fun, 0) do
    task = Task.async(fun)
    timeout = :timer.minutes(3)

    Solid.LazyCache.setup()

    if res = Solid.LazyCache.get(task) do
      res
    else
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, result} ->
          Solid.LazyCache.put(task, result, :timer.minutes(10))
          result

        nil ->
          nil
      end
    end
  end

  def apply_lazy(value), do: value
end
