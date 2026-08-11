defmodule Solid.Tag.Partial do
  @moduledoc false

  alias Solid.Context

  @spec load_template(String.t(), keyword()) :: {:ok, Solid.Template.t()} | {:error, term()}
  def load_template(template, options) do
    {file_system, instance} = options[:file_system] || {Solid.BlankFileSystem, nil}
    cache_module = Keyword.get(options, :cache_module, Solid.Caching.NoCache)

    template_str = file_system.read_template_file(template, instance)
    cache_key = :md5 |> :crypto.hash(template_str) |> Base.encode16(case: :lower)

    case apply(cache_module, :get, [cache_key]) do
      {:ok, cached_template} ->
        {:ok, cached_template}

      {:error, :not_found} ->
        with {:ok, parsed} <- Solid.parse(template_str, options) do
          apply(cache_module, :put, [cache_key, parsed])
          {:ok, parsed}
        end
    end
  end

  @spec render_isolated(Solid.Template.t(), map(), Context.t(), keyword()) ::
          {iolist(), Context.t()}
  def render_isolated(template, binding_vars, context, options) do
    case Solid.render(template, binding_vars, options) do
      {:ok, rendered_text} ->
        {rendered_text, context}

      {:error, errors, rendered_text} ->
        {rendered_text, Context.put_errors(context, Enum.reverse(errors))}
    end
  end

  @spec render_shared(Solid.Template.t(), map(), Context.t(), keyword()) ::
          {iolist(), Context.t()}
  def render_shared(template, binding_vars, context, options) do
    partial_context = merge_binding(context, binding_vars)

    case Solid.render(template.parsed_template, partial_context, options) do
      {rendered_text, updated_context} ->
        {rendered_text, merge_context_back(context, updated_context)}

      other ->
        other
    end
  catch
    {exp, rendered_text, updated_context} when exp in [:break_exp, :continue_exp] ->
      {rendered_text, merge_context_back(context, updated_context)}
  end

  defp merge_binding(context, binding_vars) do
    counter_vars = Map.merge(context.counter_vars, binding_vars)

    %{
      context
      | counter_vars: counter_vars,
        vars: Map.merge(context.vars, binding_vars),
        iteration_vars: Map.merge(context.iteration_vars, binding_vars)
    }
  end

  defp merge_context_back(context, partial_context) do
    %{
      context
      | vars: partial_context.vars,
        counter_vars: partial_context.counter_vars,
        iteration_vars: partial_context.iteration_vars,
        errors: partial_context.errors ++ context.errors
    }
  end
end
