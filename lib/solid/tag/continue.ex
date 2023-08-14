defmodule Solid.Tag.Continue do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag

  @impl true
  def spec(_parser) do
    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("continue"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(_tag, context, _options) do
    throw({:continue_exp, [], context})
  end
end
