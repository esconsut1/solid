defmodule Solid.Caching.NoCache do
  @moduledoc false
  @behaviour Solid.Caching

  @impl true
  def get(_cache_key), do: {:error, :not_found}

  @impl true
  def put(_cache_key, _value), do: :ok
end
