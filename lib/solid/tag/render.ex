defmodule Solid.Tag.Render do
  @moduledoc false
  @behaviour Solid.Tag

  import NimbleParsec

  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    BaseTag.opening_tag()
    |> ignore()
    |> ignore(string("render"))
    |> ignore(space)
    |> tag(Argument.argument(), :template)
    |> tag(
      optional(
        string(",")
        |> ignore()
        |> ignore(space)
        |> concat(Argument.named_arguments())
      ),
      :arguments
    )
    |> tag(
      optional(
        space
        |> ignore()
        |> concat(Argument.with_parameter())
      ),
      :with_parameter
    )
    |> ignore(space)
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([template: template_binding, arguments: argument_binding, with_parameter: with_binding], context, options) do
    {:ok, template, context} = Solid.Argument.get(template_binding, context)

    {:ok, binding_vars, context} =
      (argument_binding || [])
      |> Keyword.get(:named_arguments, [])
      |> Keyword.merge(Enum.reverse(Keyword.get(with_binding || [], :with_parameter, [])))
      |> Solid.Argument.parse_named_arguments(context)

    binding_vars =
      binding_vars
      |> Enum.concat()
      |> Map.new()

    {file_system, instance} = options[:file_system] || {Solid.BlankFileSystem, nil}

    template_str = file_system.read_template_file(template, instance)
    template = Solid.parse!(template_str, options)
    # FIXME need to sort out context error stuff :thinking: + tests
    case Solid.render(template, binding_vars, options) do
      {:ok, rendered_text} ->
        {[text: rendered_text], context}

      {:error, errors, rendered_text} ->
        {[text: rendered_text], Solid.Context.put_errors(context, Enum.reverse(errors))}
    end
  end
end
