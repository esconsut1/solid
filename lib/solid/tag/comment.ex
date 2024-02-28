defmodule Solid.Tag.Comment do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag

  @impl true
  def spec(_parser) do
    end_comment_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("endcomment"))
      |> ignore(BaseTag.closing_tag())

    comment =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("comment"))
      |> ignore(BaseTag.closing_tag())
      |> ignore(repeat(end_comment_tag |> ignore() |> lookahead_not() |> utf8_char([])))
      |> ignore(end_comment_tag)

    inline_comment =
      BaseTag.comment_tag()
      |> ignore()
      |> ignore(repeat(BaseTag.closing_tag() |> ignore() |> lookahead_not() |> utf8_char([])))
      |> ignore(BaseTag.closing_tag())

    choice([comment, inline_comment])
  end

  @impl true
  def render(_tag, context, _options) do
    {[], context}
  end
end
