defmodule Solid.Tag.EchoTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Echo

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Echo.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = Parser.parse("{% echo 'abc' | upcase %}")
    context = %Context{}
    assert {[text: "ABC"], ^context} = Echo.render(parsed, context, [])
  end
end
