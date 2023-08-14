defmodule Solid.LazyCache do
  @moduledoc false

  @cache :solid_lazy_cache

  def setup do
    if :ets.whereis(@cache) == :undefined do
      :ets.new(@cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

      :ets.insert(@cache, {:__max_size, 1000, nil})
    end

    :ok
  end

  def get(key) do
    entry = :ets.lookup(@cache, key)

    with [{_key, value, expiry}] <- entry,
         true <- :erlang.system_time(:second) > expiry do
      value
    else
      [] ->
        nil

      false ->
        :ets.delete(@cache, key)
        nil
    end
  end

  def put(key, value, ttl) do
    expires = :erlang.system_time(:second) + ttl
    entry = {key, value, expires}

    if !exists?(key) && :ets.info(@cache, :size) > get_max_size() do
      purge()
    end

    :ets.insert(@cache, entry)
  end

  def exists?(key) do
    :ets.member(@cache, key)
  end

  defp get_max_size do
    [{_key, max_size, _expiry}] = :ets.lookup(@cache, :__max_size)
    max_size
  end

  def purge do
    purge(:ets.first(@cache), 1)
  end

  defp purge(_, 100), do: :ok

  defp purge(:"$end_of_table", _), do: :ok

  defp purge(key, count) do
    :ets.delete(@cache, key)
    purge(:ets.next(@cache, key), count + 1)
  end
end
