defmodule Solid.Caching do
  @moduledoc false
  @callback get(key :: term) :: {:ok, Solid.Template.t()} | {:error, :not_found}

  @callback put(key :: term, Solid.Template.t()) :: :ok | {:error, term}
end
