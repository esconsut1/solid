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
      |> concat(
        BaseTag.closing_tag()
        |> lookahead_not()
        |> utf8_char([])
        |> repeat()
        |> reduce({List, :to_string, []})
      )
      |> ignore(BaseTag.closing_tag())
      |> post_traverse({__MODULE__, :validate_inline_comment, []})

    choice([comment, inline_comment])
  end

  @impl true
  def render(_tag, context, _options) do
    {[], context}
  end

  @doc false
  def validate_inline_comment(rest, args, context, _line, _offset) do
    markup =
      case args do
        [body] when is_binary(body) -> body
        _ -> ""
      end

    if invalid_inline_comment?(markup) do
      {:error, "invalid inline comment"}
    else
      {rest, [], context}
    end
  end

  defp invalid_inline_comment?(markup) do
    Regex.match?(~r/\n\s*[^#\s]/, markup)
  end
end
