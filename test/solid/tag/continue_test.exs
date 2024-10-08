defmodule Solid.Tag.ContinueTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Continue

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Continue.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = Parser.parse("{% continue %}")

    assert catch_throw(Continue.render(parsed, %Context{}, [])) ==
             {:continue_exp, [], %Solid.Context{}}
  end
end
