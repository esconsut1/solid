defmodule Solid.Forloop do
  @moduledoc false

  @spec build(non_neg_integer(), non_neg_integer(), map() | nil) :: map()
  def build(index, loop_length, parentloop \\ nil) do
    %{
      "index" => index + 1,
      "index0" => index,
      "rindex" => loop_length - index,
      "rindex0" => loop_length - index - 1,
      "first" => index == 0,
      "last" => loop_length == index + 1,
      "length" => loop_length,
      "parentloop" => parentloop
    }
  end
end
