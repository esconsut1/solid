defmodule Solid.Utils do
  @moduledoc false

  def apply_lazy(fun) when is_function(fun, 0) do
    task = Task.async(fun)

    case Task.yield(task, :timer.minutes(3)) || Task.shutdown(task) do
      {:ok, result} -> result
      _ -> nil
    end
  end

  def apply_lazy(value), do: value
end
