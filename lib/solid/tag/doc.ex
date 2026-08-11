defmodule Solid.Tag.Doc do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    end_doc_tag =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("enddoc"))
      |> ignore(BaseTag.closing_tag())

    nested_doc =
      BaseTag.opening_tag()
      |> ignore()
      |> ignore(string("doc"))
      |> ignore(space)
      |> ignore(BaseTag.closing_tag())

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("doc"))
    |> ignore(space)
    |> ignore(BaseTag.closing_tag())
    |> ignore(
      repeat(
        nested_doc
        |> ignore()
        |> lookahead_not()
        |> concat(end_doc_tag |> ignore() |> lookahead_not())
        |> utf8_char([])
      )
    )
    |> ignore(end_doc_tag)
  end

  @impl true
  def render(_tag, context, _options) do
    {[], context}
  end
end
