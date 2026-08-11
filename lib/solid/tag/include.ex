defmodule Solid.Tag.Include do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Forloop
  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal
  alias Solid.Tag.Partial
  alias Solid.Utils

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("include"))
    |> ignore(space)
    |> tag(Argument.argument(), :template)
    |> tag(
      optional(
        space
        |> ignore()
        |> concat(Argument.with_or_for_parameter())
      ),
      :with_or_for_parameter
    )
    |> tag(
      optional(
        space
        |> ignore()
        |> ignore(string(","))
        |> ignore(space)
        |> concat(Argument.named_arguments())
      ),
      :arguments
    )
    |> ignore(space)
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(tag, context, options) do
    template_binding = Keyword.fetch!(tag, :template)
    argument_binding = Keyword.get(tag, :arguments, [])
    with_or_for = Keyword.get(tag, :with_or_for_parameter, [])

    {:ok, template_name, context} = Solid.Argument.get(template_binding, context, options)

    {:ok, binding_vars, context} =
      argument_binding
      |> Keyword.get(:named_arguments, [])
      |> Solid.Argument.parse_named_arguments(context, options)

    binding_vars = binding_vars |> Enum.concat() |> Map.new()
    alias_name = default_alias(template_name, with_or_for)

    case Partial.load_template(template_name, options) do
      {:ok, template} ->
        render_partial(template, binding_vars, with_or_for, alias_name, context, options)

      {:error, exception} ->
        {[], Solid.Context.put_errors(context, [exception])}
    end
  end

  defp default_alias(_template_name, for_parameter: [_, alias_name]), do: alias_name
  defp default_alias(_template_name, with_parameter: [_, alias_name]), do: alias_name

  defp default_alias(template_name, _) do
    template_name
    |> to_string()
    |> String.split("/")
    |> List.last()
  end

  defp render_partial(template, binding_vars, with_or_for, alias_name, context, options) do
    case with_or_for do
      [for_parameter: [variable, ^alias_name]] ->
        render_for_loop(template, variable, alias_name, binding_vars, context, options)

      [for_parameter: [variable, item_alias]] ->
        render_for_loop(template, variable, item_alias, binding_vars, context, options)

      [with_parameter: [variable, alias_name]] ->
        render_with(template, variable, alias_name, binding_vars, context, options)

      _ ->
        {:ok, value, context} = Solid.Argument.get([field: [alias_name]], context, options)
        binding_vars = Map.put(binding_vars, alias_name, value)
        {rendered, context} = Partial.render_shared(template, binding_vars, context, options)
        {[text: rendered], context}
    end
  end

  defp render_with(template, variable, alias_name, binding_vars, context, options) do
    {:ok, value, context} = Solid.Argument.get(variable, context, options)
    binding_vars = Map.put(binding_vars, alias_name, value)
    {rendered, context} = Partial.render_shared(template, binding_vars, context, options)
    {[text: rendered], context}
  end

  defp render_for_loop(template, variable, alias_name, binding_vars, context, options) do
    {:ok, collection, context} = Solid.Argument.get(variable, context, options)
    collection = Utils.enumerable_to_list(collection || [])

    {result, context} =
      collection
      |> Enum.with_index()
      |> Enum.reduce({[], context}, fn {item, index}, {acc, context} ->
        forloop = Forloop.build(index, length(collection))
        item_binding = Map.merge(binding_vars, %{alias_name => item, "forloop" => forloop})
        {rendered, context} = Partial.render_shared(template, item_binding, context, options)
        {[rendered | acc], context}
      end)

    {[text: Enum.reverse(result)], context}
  end
end
