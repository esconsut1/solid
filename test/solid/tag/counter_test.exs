defmodule Solid.Tag.CounterTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Counter

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Counter.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = Parser.parse("{% increment my_number %}")

    assert {[text: "4"], context} =
             Counter.render(parsed, %Context{counter_vars: %{"my_number" => 4}}, [])

    assert context.counter_vars == %{"my_number" => 5}
  end
end
