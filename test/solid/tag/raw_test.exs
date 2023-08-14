defmodule Solid.Tag.RawTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Raw

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Raw.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} =
      Parser.parse("{% raw %} {{liquid}} {% increment counter %} {% endraw %}")

    assert {[text: ~c" {{liquid}} {% increment counter %} "], %Context{}} ==
             Raw.render(parsed, %Context{}, [])
  end
end
