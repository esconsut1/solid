defmodule Solid.Tag.AssignTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Assign

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Assign.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = Parser.parse("{% assign first = 3 %}")

    assert {[], context} = Assign.render(parsed, %Context{}, [])

    assert context.vars == %{"first" => 3}
  end
end
