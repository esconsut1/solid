defmodule Solid.Tag.Liquid do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.BaseTag

  @impl true
  def spec(_parser) do
    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("liquid"))
    |> concat(
      "%}"
      |> string()
      |> lookahead_not()
      |> utf8_char([])
      |> repeat()
      |> reduce({List, :to_string, []})
    )
    |> ignore(string("%}"))
  end

  @impl true
  def render([body], context, options) when is_binary(body) do
    parsed = parse_body(body)
    {result, context} = Solid.render(parsed, context, options)
    {[text: result], context}
  end

  def render(body, context, options) when is_binary(body) do
    render([body], context, options)
  end

  @doc false
  def parse_body(body) do
    body
    |> liquid_body_to_template()
    |> Solid.parse!()
    |> Map.fetch!(:parsed_template)
  end

  defp liquid_body_to_template(body) do
    body
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&comment_line?/1)
    |> Enum.map_join("\n", fn line -> "{% #{line} %}" end)
  end

  defp comment_line?(line) do
    String.starts_with?(line, "#")
  end
end
