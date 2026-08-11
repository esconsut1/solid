defmodule Solid.Indifferent do
  @moduledoc false
  def get(map, key, default \\ nil) do
    case fetch(map, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def fetch(data, key) do
    case access(data, key) do
      {:ok, _} = result ->
        result

      :error ->
        # try either a string or an existing atom (avoid creating new atoms)
        cond do
          is_binary(key) -> access(data, existing_or_new_atom(key))
          is_atom(key) -> access(data, Atom.to_string(key))
          true -> :error
        end
    end
  end

  defp existing_or_new_atom(bin) when is_binary(bin) do
    :erlang.binary_to_existing_atom(bin, :utf8)
  rescue
    ArgumentError -> String.to_atom(bin)
  catch
    :error -> String.to_atom(bin)
  end

  # Access a map/struct by key using either Map.fetch/2 or Access.fetch/2
  defp access(data, key) when is_struct(data) do
    # Structs don't allow Access.fetch/2 access without implementing Access so
    # fallback to Map.fetch/2
    if implements_behaviour?(data, Access) do
      Access.fetch(data, key)
    else
      Map.fetch(data, key)
    end
  end

  defp access(data, key), do: Access.fetch(data, key)

  defp implements_behaviour?(map, behaviour) when is_struct(map) do
    map.__struct__.module_info()[:attributes]
    |> Keyword.get(:behaviour, [])
    |> Enum.member?(behaviour)
  end

  defp implements_behaviour?(_, _), do: false
end
