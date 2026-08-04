# Solid

[![Build Status](https://github.com/edgurgel/solid/workflows/CI/badge.svg?branch=main)](https://github.com/edgurgel/solid/actions?query=workflow%3ACI)
[![Module Version](https://img.shields.io/hexpm/v/solid.svg)](https://hex.pm/packages/solid)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/solid/)
[![Total Download](https://img.shields.io/hexpm/dt/solid.svg)](https://hex.pm/packages/solid)
[![License](https://img.shields.io/hexpm/l/solid.svg)](https://github.com/edgurgel/solid/blob/main/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/edgurgel/solid.svg)](https://github.com/edgurgel/solid/commits/main)

Solid is an implementation in Elixir of the template language [Liquid](https://shopify.github.io/liquid/). It uses [nimble_parsec](https://github.com/dashbitco/nimble_parsec) to generate the parser.

Standard filters and tags aim to match [Shopify/liquid](https://github.com/Shopify/liquid) behavior. Integration cases under `test/cases` are rendered against the Ruby Liquid gem for parity.

## Basic Usage

```elixir
iex> template = "My name is {{ user.name }}"
iex> {:ok, template} = Solid.parse(template)
iex> Solid.render!(template, %{ "user" => %{ "name" => "José" } }) |> to_string
"My name is José"
```

## Installation

The package can be installed with:

```elixir
def deps do
  [{:solid, "~> 0.15"}]
end
```

## Standard filters

`Solid.Filter` implements Shopify Liquid’s standard filters, including:

- **Strings:** `append`, `capitalize`, `downcase`, `upcase`, `lstrip`, `rstrip`, `strip`, `squish`, `prepend`, `remove`, `remove_first`, `remove_last`, `replace`, `replace_first`, `replace_last`, `split`, `truncate`, `truncatewords`, `strip_newlines`, `newline_to_br`, `strip_html`, `escape`, `escape_once`, `url_encode`, `url_decode`, `base64_encode`, `base64_decode`, `base64_url_safe_encode`, `base64_url_safe_decode`
- **Arrays:** `compact`, `concat`, `first`, `last`, `join`, `map`, `reverse`, `size`, `slice`, `sort`, `sort_natural`, `uniq`, `where`, `reject`, `has`, `find`, `find_index`, `sum`
- **Math:** `abs`, `at_least`, `at_most`, `ceil`, `divided_by`, `floor`, `minus`, `modulo`, `plus`, `round`, `times`
- **Other:** `date`, `default`

Property-based variants are supported where Liquid supports them (for example `sort: "price"`, `uniq: "type"`, `sum: "price"`, `where` / `reject` / `has` / `find` / `find_index`).

`default` accepts Liquid’s `allow_false` option:

```liquid
{{ false | default: "fallback", allow_false: true }}
```

### Safe failure behavior

Unknown filters return the input unchanged (unless `strict_filters: true`).

For known filters, Solid avoids raising on type / clause mismatches: unmatched or invalid input typically returns the original value (or Liquid’s documented empty/`nil`/`[]` result). Examples: invalid Base64 decode returns the input; `concat` with a non-array argument returns the input; division by zero returns the input.

## Custom tags

To implement a new tag you need to create a new module that implements the `Tag` behaviour:

```elixir
defmodule MyCustomTag do
  import NimbleParsec
  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Solid.Parser.Literal.whitespace(min: 0)

    ignore(string("{%"))
    |> ignore(space)
    |> ignore(string("my_tag"))
    |> ignore(space)
    |> ignore(string("%}"))
  end

  @impl true
  def render(_tag, _context, _options) do
    [text: "my first tag"]
  end
end
```

- `spec` defines how to parse your tag;
- `render` defines how to render your tag.

Now we need to add the tag to the parser

```elixir
defmodule MyParser do
  use Solid.Parser.Base, custom_tags: [MyCustomTag]
end
```

And finally pass the custom parser as an option:

```elixir
"{% my_tag %}"
|> Solid.parse!(parser: MyParser)
|> Solid.render()
```

## Custom filters

While calling `Solid.render` one can pass a module with custom filters:

```elixir
defmodule MyCustomFilters do
  def add_one(x), do: x + 1
end

"{{ number | add_one }}"
|> Solid.parse!()
|> Solid.render(%{ "number" => 41}, custom_filters: MyCustomFilters)
|> IO.puts()
# 42
```

Extra options can be passed as last argument to custom filters if an extra argument is accepted:

```elixir
defmodule MyCustomFilters do
  def asset_url(path, opts) do
    opts[:host] <> path
  end
end

opts = [custom_filters: MyCustomFilters, host: "http://example.com"]

"{{ file_path | asset_url }}"
|> Solid.parse!()
|> Solid.render(%{ "file_path" => "/styles/app.css"}, opts)
|> IO.puts()
# http://example.com/styles/app.css
```

Custom filters always take precedence over `Solid.Filter`. Standard filters remain available when the custom module does not define them.

## Strict rendering

`Solid.render/3` doesn't raise or return errors unless `strict_variables: true` or `strict_filters: true` are passed as options.

If there are any missing variables/filters `Solid.render/3` returns `{:error, errors, result}` where errors is the list of collected errors and `result` is the rendered template.

`Solid.render!/3` raises if `strict_variables: true` is passed and there are missing variables.
`Solid.render!/3` raises if `strict_filters: true` is passed and there are missing filters.

## File system

By default Solid uses `Solid.BlankFileSystem`, which raises `Solid.FileSystem.Error` when `{% render %}` / includes are used.

Use `Solid.LocalFileSystem` (or your own `Solid.FileSystem` implementation) via the `file_system` option:

```elixir
fs = Solid.LocalFileSystem.new("/path/to/templates")
Solid.render!(template, vars, file_system: {Solid.LocalFileSystem, fs})
```

## Caching

In order to cache `render`-ed templates, you can write your own cache adapter. It should implement behaviour `Solid.Caching`. By default it uses `Solid.Caching.NoCache` trivial adapter.

If you want to use for example [Cachex](https://github.com/whitfin/cachex) for that such implemention would look like:

```elixir
defmodule CachexCache do
  @behaviour Solid.Caching

  @impl true
  def get(key) do
    case Cachex.get(:your_cache_name, key) do
      {_, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, value}
      {:error, error_msg} -> {:error, error_msg}
    end
  end

  @impl true
  def put(key, value) do
    case Cachex.put(:my_cache, key, value) do
      {:ok, true} -> :ok
      {:error, error_msg} -> {:error, error_msg}
    end
  end
end
```

And then pass it as an option to render `cache_module: CachexCache`.

## Using structs in context

In order to pass structs to context you need to implement protocol `Solid.Matcher` for that. That protocol consist of one function `def match(data, keys)`. First argument is struct being provided and second is list of string, which are keys passed after `.` to the struct.

For example:

```elixir
defmodule UserProfile do
  defstruct [:full_name]

  defimpl Solid.Matcher do
    def match(user_profile, ["full_name"]), do: {:ok, user_profile.full_name}
  end
end

defmodule User do
  defstruct [:email]

  def load_profile(%User{} = _user) do
    # implementation omitted
    %UserProfile{full_name: "John Doe"}
  end

  defimpl Solid.Matcher do
    def match(user, ["email"]), do: {:ok, user.email}
    def match(user, ["profile" | keys]), do: user |> User.load_profile() |> @protocol.match(keys)
  end
end

template = ~s({{ user.email}}: {{ user.profile.full_name }})
context = %{
  "user" => %User{email: "test@example.com"}
}

template |> Solid.parse!() |> Solid.render!(context) |> to_string()
# => test@example.com: John Doe
```

If the `Solid.Matcher` protocol is not enough one can provide their own module like this:

```elixir
defmodule MyMatcher do
  def match(data, keys), do: {:ok, 42}
end

# ...
Solid.render(template, %{"number" => 4}, matcher_module: MyMatcher)
```

## Contributing

When adding new functionality or fixing bugs, add a case under `test/cases` when it makes sense. Those cases are compared to the Ruby [liquid](https://github.com/Shopify/liquid) gem via `test/liquid.rb`.

For integration tests:

1. Install Ruby (see `.tool-versions`) and run `bundle install`
2. Run `mix test`

## Copyright and License

Copyright (c) 2016-2026 Eduardo Gurgel Pinho

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
