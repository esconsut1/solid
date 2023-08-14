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
    :ets.insert(@cache, {key, value, expires})
  end
end
