defmodule Solid.Tag.Raw do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag

  @impl true
  def spec(_parser) do
    end_raw_tag =
      BaseTag.opening_tag()
      |> ignore(string("endraw"))
      |> ignore(BaseTag.closing_tag())

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("raw"))
    |> ignore(BaseTag.closing_tag())
    |> repeat(end_raw_tag |> ignore() |> lookahead_not() |> utf8_char([]))
    |> ignore(end_raw_tag)
  end

  @impl true
  def render(raw, context, _options) do
    {[text: raw], context}
  end
end
