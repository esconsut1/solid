defmodule Solid.UndefinedVariableError do
  defexception [:variable]

  @impl true
  def message(exception), do: "Undefined variable #{exception.variable}"
end

defmodule Solid.UndefinedFilterError do
  defexception [:filter]

  @impl true
  def message(exception), do: "Undefined filter #{exception.filter}"
end

defmodule Solid.Context do
  defstruct vars: %{}, counter_vars: %{}, iteration_vars: %{}, cycle_state: %{}, errors: []

  @type t :: %__MODULE__{
          vars: map,
          counter_vars: map,
          iteration_vars: %{optional(String.t()) => term},
          cycle_state: map,
          errors: list(Solid.UndefinedVariableError)
        }
  @type scope :: :counter_vars | :vars | :iteration_vars

  def put_errors(context, errors) when is_list(errors) do
    %{context | errors: errors ++ context.errors}
  end

  def put_errors(context, error) do
    %{context | errors: [error | context.errors]}
  end

  @doc """
  Get data from context respecting the scope order provided.

  Possible scope values: :counter_vars, :vars or :iteration_vars
  """
  @spec get_in(t(), [term()], [scope]) :: {:ok, term} | {:error, {:not_found, [term()]}}
  def get_in(context, key, scopes) do
    scopes
    |> Enum.reverse()
    |> Enum.map(&get_from_scope(context, &1, key))
    |> Enum.reduce({:error, {:not_found, key}}, fn
      {:ok, nil}, acc = {:ok, _} -> acc
      value = {:ok, _}, _acc -> value
      _value, acc -> acc
    end)
  end

  @doc """
  Find the current value that `cycle` must return
  """
  @spec run_cycle(t(), [values: [String.t()]] | [name: String.t(), values: [String.t()]]) ::
          {t(), String.t()}
  def run_cycle(%__MODULE__{cycle_state: cycle_state} = context, cycle) do
    name = Keyword.get(cycle, :name, cycle[:values])

    case cycle_state[name] do
      {current_index, cycle_map} ->
        limit = map_size(cycle_map)
        next_index = if current_index + 1 < limit, do: current_index + 1, else: 0

        {%{context | cycle_state: %{context.cycle_state | name => {next_index, cycle_map}}},
         cycle_map[next_index]}

      nil ->
        values = Keyword.fetch!(cycle, :values)
        cycle_map = cycle_to_map(values)
        current_index = 0

        {%{context | cycle_state: Map.put_new(cycle_state, name, {current_index, cycle_map})},
         cycle_map[current_index]}
    end
  end

  defp cycle_to_map(cycle) do
    cycle
    |> Enum.with_index()
    |> Enum.into(%{}, fn {value, index} -> {index, value} end)
  end

  defp get_from_scope(context, scope, key) do
    Map.get(context, scope) |> do_get_in(key)
  end

  defp do_get_in(nil, []), do: {:ok, nil}
  defp do_get_in(nil, _), do: {:error, :not_found}
  defp do_get_in(data, []), do: {:ok, data}

  defp do_get_in(data, ["size"]) when is_list(data) do
    {:ok, length(data)}
  end

  defp do_get_in(data, ["size"]) when is_struct(data) do
    {:ok, Map.get(data, "size", data |> Map.from_struct() |> Enum.count())}
  end

  defp do_get_in(data, ["size"]) when is_map(data) do
    {:ok, Map.get(data, "size", Enum.count(data))}
  end

  defp do_get_in(data, ["size"]) when is_binary(data) do
    {:ok, String.length(data)}
  end

  defp do_get_in(data, ["first" | keys]) when is_list(data) do
    List.first(data) |> apply_lazy |> do_get_in(keys)
  end

  defp do_get_in(data, ["first" | keys]) when is_binary(data) do
    String.first(data) |> do_get_in(keys)
  end

  defp do_get_in(data, ["last" | keys]) when is_list(data) do
    List.last(data) |> apply_lazy |> do_get_in(keys)
  end

  defp do_get_in(data, ["last" | keys]) when is_binary(data) do
    String.last(data) |> do_get_in(keys)
  end

  defp do_get_in(data, [key | keys]) when is_map(data) and is_atom(key) do
    case Map.fetch(data, key) do
      {:ok, value} -> apply_lazy(value) |> do_get_in(keys)
      _ -> {:error, :not_found}
    end
  end

  defp do_get_in(data, [key | keys]) when is_map(data) do
    case Map.fetch(data, key) do
      {:ok, value} when is_tuple(value) -> Tuple.to_list(value) |> do_get_in(keys)
      {:ok, value} -> apply_lazy(value) |> do_get_in(keys)
      _ -> do_get_in(data, [String.to_atom(key) | keys])
    end
  end

  defp do_get_in(data, [key | keys]) when is_integer(key) and is_list(data) do
    case Enum.fetch(data, key) do
      {:ok, value} -> apply_lazy(value) |> do_get_in(keys)
      _ -> {:error, :not_found}
    end
  end

  defp do_get_in(_, _), do: {:error, :not_found}

  defp apply_lazy(fun) when is_function(fun, 0) do
    task = Task.async(fun)
    timeout = :timer.minutes(3)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> nil
    end
  end

  defp apply_lazy(value), do: value
end
