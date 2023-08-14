defmodule Solid.Tag.CommentTest do
  use ExUnit.Case, async: true

  alias Solid.Context
  alias Solid.Tag.Comment

  defmodule Parser do
    @moduledoc false
    import NimbleParsec

    defparsec(:parse, __MODULE__ |> Comment.spec() |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = Parser.parse("{% comment %} a comment {% endcomment %}")

    assert {[], %Context{}} == Comment.render(parsed, %Context{}, [])
  end
end
