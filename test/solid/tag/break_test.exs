defmodule Solid.Tag.BreakTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Break

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Break.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = Parser.parse("{% break %}")

    assert catch_throw(Break.render(parsed, %Context{}, [])) ==
             {:break_exp, [], %Solid.Context{}}
  end
end
