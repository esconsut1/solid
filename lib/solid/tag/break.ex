defmodule Solid.Tag.Break do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag

  @impl true
  def spec(_parser) do
    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("break"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(_tag, context, _options) do
    throw({:break_exp, [], context})
  end
end
