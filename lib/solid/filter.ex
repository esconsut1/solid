defmodule Solid.Filter do
  @moduledoc """
  Standard filters
  """

  import Kernel, except: [abs: 1, ceil: 1, round: 1, floor: 1, apply: 2]

  @doc """
  Apply `filter` if it exists. Otherwise return the first input.

  iex> Solid.Filter.apply("upcase", ["ac"], [])
  {:ok, "AC"}
  iex> Solid.Filter.apply("no_filter_here", [1, 2, 3], [])
  {:ok, 1}
  iex> Solid.Filter.apply("no_filter_here", [1, 2, 3], [strict_filters: true])
  {:error, %Solid.UndefinedFilterError{filter: "no_filter_here"}, 1}
  """
  def apply(filter, args, opts) do
    custom_module = opts[:custom_filters] || Application.get_env(:solid, :custom_filters)
    strict_variables = Keyword.get(opts, :strict_filters, false)
    args_with_opts = args ++ [opts]

    result =
      if is_atom(custom_module) and custom_module != __MODULE__ do
        with :error <- apply_filter(custom_module, filter, args_with_opts),
             :error <- apply_filter(custom_module, filter, args),
             do: apply_filter(__MODULE__, filter, args)
      else
        apply_filter(__MODULE__, filter, args)
      end

    case result do
      {:ok, value} ->
        {:ok, value}

      :error ->
        if strict_variables do
          {:error, %Solid.UndefinedFilterError{filter: filter}, List.first(args)}
        else
          {:ok, List.first(args)}
        end
    end
  end

  defp apply_filter(mod, func, args) do
    case safe_existing_atom(func) do
      {:ok, func_atom} ->
        if function_exported?(mod, func_atom, length(args)) do
          try do
            {:ok, Kernel.apply(mod, func_atom, args)}
          rescue
            FunctionClauseError -> :error
          end
        else
          :error
        end

      :error ->
        :error
    end
  end

  defp safe_existing_atom(func) do
    {:ok, String.to_existing_atom(func)}
  rescue
    ArgumentError -> :error
  end

  defp any_to_float(string) when byte_size(string) > 0 do
    case Float.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp any_to_float(number) when is_number(number), do: number
  defp any_to_float(_), do: nil

  defp number_trunc(number) do
    number
    |> to_string()
    |> String.split(".", trim: true)
    |> _number_trunc()
  end

  defp _number_trunc([head]), do: String.to_integer(head)
  defp _number_trunc([head, "0"]), do: String.to_integer(head)

  defp _number_trunc([head, tail]) do
    float = head <> "." <> tail

    case Float.parse(float) do
      {float, ""} -> float
      _ -> nil
    end
  end

  defp as_array(input) when is_list(input), do: List.flatten(input)
  defp as_array(input) when is_map(input) and not is_struct(input), do: [input]
  defp as_array(nil), do: []
  defp as_array(input), do: [input]

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true

  defp blank?(nil), do: true
  defp blank?(false), do: true
  defp blank?([]), do: true
  defp blank?(""), do: true
  defp blank?(input) when is_map(input) and not is_struct(input), do: map_size(input) == 0
  defp blank?(_), do: false

  defp integer_like?(operand) when is_integer(operand), do: true

  defp integer_like?(operand) when is_binary(operand) do
    case Integer.parse(operand) do
      {_i, ""} -> true
      _ -> false
    end
  end

  defp integer_like?(_), do: false

  defp nil_safe_lte?(a, b) do
    cond do
      is_nil(a) and is_nil(b) -> true
      is_nil(a) -> false
      is_nil(b) -> true
      true -> a <= b
    end
  end

  defp nil_safe_casey_lte?(a, b) do
    cond do
      is_nil(a) and is_nil(b) -> true
      is_nil(a) -> false
      is_nil(b) -> true
      true -> String.downcase(to_string(a)) <= String.downcase(to_string(b))
    end
  end

  defp filter_array(input, property, target_value, default, fun) do
    ary = as_array(input)

    if ary == [] do
      default
    else
      fun.(ary, fn
        item when is_map(item) ->
          if is_nil(target_value) do
            truthy?(item[property])
          else
            item[property] == target_value
          end

        _item ->
          false
      end)
    end
  end

  @doc """
  Returns the absolute value of a number.

  iex> Solid.Filter.abs(-17)
  17
  iex> Solid.Filter.abs(17)
  17
  iex> Solid.Filter.abs("-17.5")
  17.5
  """
  @spec abs(number | String.t()) :: number
  def abs(input) when is_binary(input) do
    if i = any_to_float(input), do: Kernel.abs(i), else: input
  end

  def abs(input) when is_number(input), do: Kernel.abs(input)
  def abs(input), do: input

  @doc """
  Concatenates two strings and returns the concatenated value.

  iex> Solid.Filter.append("www.example.com", "/index.html")
  "www.example.com/index.html"
  """
  @spec append(any, any) :: String.t()
  def append(input, string), do: "#{input}#{string}"

  @doc """
  Limits a number to a minimum value.

  iex> Solid.Filter.at_least(5, 3)
  5
  iex> Solid.Filter.at_least(2, 4)
  4
  """
  @spec at_least(any, any) :: number
  def at_least(input, minimum) do
    a = any_to_float(input)
    b = any_to_float(minimum)

    if a && b, do: a |> max(b) |> number_trunc(), else: input
  end

  @doc """
  Limits a number to a maximum value.

  iex> Solid.Filter.at_most(5, 3)
  3
  iex> Solid.Filter.at_most(2, 4)
  2
  """
  @spec at_most(any, any) :: number
  def at_most(input, maximum) do
    a = any_to_float(input)
    b = any_to_float(maximum)

    if a && b, do: a |> min(b) |> number_trunc(), else: input
  end

  @doc """
  Makes the first character of a string capitalized.

  iex> Solid.Filter.capitalize("my great title")
  "My great title"
  iex> Solid.Filter.capitalize(1)
  "1"
  """
  @spec capitalize(any) :: String.t()
  def capitalize(input), do: input |> to_string() |> String.capitalize()

  @doc """
  Rounds the input up to the nearest whole number. Liquid tries to convert the input to a number before the filter is applied.
  """
  @spec ceil(number | String.t()) :: number
  def ceil(input) when is_binary(input) do
    if i = any_to_float(input), do: Kernel.ceil(i), else: input
  end

  def ceil(input) when is_number(input), do: Kernel.ceil(input)
  def ceil(input), do: input

  @doc """
  Converts a `DateTime`/`NaiveDateTime` struct into another date format.
  The input may also be a Unix timestamp or an ISO 8601 date string.

  The format for this syntax is the same as `Timex.format/3`.

  To get the current time, pass the special word `"now"` (or `"today"`) to `date`.

  iex> Solid.Filter.date("1970-01-01 00:00:00Z", "%s")
  "0"
  iex> Solid.Filter.date("1970-01-01 00:00:01Z", "%s")
  "1"
  """
  @spec date(DateTime.t() | NaiveDateTime.t() | integer() | String.t(), String.t()) :: String.t()
  def date(input, format \\ "%F %T")
  def date(nil, _), do: nil
  def date(input, nil), do: date(input)
  def date(input, ""), do: date(input)
  def date(input, []), do: date(input)

  def date(input, format) when input in ["now", "today"] do
    :calendar.local_time() |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC") |> date(format)
  end

  def date(input, format) when is_binary(input) do
    case NaiveDateTime.from_iso8601(input) do
      {:ok, input_date} ->
        date(input_date, format)

      {:error, :invalid_format} ->
        case Timex.parse(input, "%a %b %d %T %Y", :strftime) do
          {:ok, input_date} -> date(input_date, format)
          _ -> input
        end
    end
  end

  def date(input, format) when is_integer(input) do
    input |> Timex.from_unix() |> date(format)
  rescue
    _ -> input
  end

  def date(input, format) do
    case Timex.format(input, format, :strftime) do
      {:ok, date_str} -> date_str
      _ -> input
    end
  end

  @doc """
  Allows you to specify a fallback in case a value doesn’t exist.
  `default` will show its value if the left side is nil, false, or empty

  iex> Solid.Filter.default(123, 456)
  123

  iex> Solid.Filter.default(nil, 456)
  456

  iex> Solid.Filter.default(false, 456)
  456

  iex> Solid.Filter.default([], 456)
  456

  iex> Solid.Filter.default(false, 456, %{"allow_false" => true})
  false
  """
  @spec default(any, any) :: any
  @spec default(any, any, map) :: any
  def default(input, value \\ "", options \\ %{})

  def default(input, value, options) when is_map(options) do
    allow_false = Map.get(options, "allow_false") || Map.get(options, :allow_false)

    cond do
      allow_false && is_nil(input) -> value
      allow_false && blank?(input) && not is_boolean(input) -> value
      allow_false -> input
      blank?(input) -> value
      true -> input
    end
  end

  def default(input, value, _), do: default(input, value, %{})

  @doc """
  Divides a number by the specified number.

  The result is rounded down to the nearest integer (that is, the floor) if the divisor is an integer.

  {{ 16 | divided_by: 4 }}
  iex> Solid.Filter.divided_by(16, 4)
  4
  iex> Solid.Filter.divided_by(5, 3)
  1
  iex> Solid.Filter.divided_by(20, 7)
  2
  iex> Solid.Filter.divided_by(20, 7.0)
  2.857142857142857
  """
  @spec divided_by(any, any) :: number
  def divided_by(input, operand) do
    a = any_to_float(input)
    b = any_to_float(operand)

    cond do
      is_nil(a) or is_nil(b) ->
        input

      b == 0 ->
        input

      integer_like?(operand) ->
        (a / b) |> Float.floor() |> trunc()

      true ->
        a / b
    end
  end

  @doc """
  Makes each character in a string uppercase.
  It has no effect on strings which are already all uppercase.

  iex> Solid.Filter.upcase("aBc")
  "ABC"

  iex> Solid.Filter.upcase(456)
  "456"

  iex> Solid.Filter.upcase(nil)
  ""
  """
  @spec upcase(any) :: String.t()
  def upcase(input), do: input |> to_string() |> String.upcase()

  @doc """
  Makes each character in a string lowercase.
  It has no effect on strings which are already all lowercase.

  iex> Solid.Filter.downcase("aBc")
  "abc"

  iex> Solid.Filter.downcase(456)
  "456"

  iex> Solid.Filter.downcase(nil)
  ""
  """
  @spec downcase(any) :: String.t()
  def downcase(input), do: input |> to_string() |> String.downcase()

  @doc """
  Returns the first item of an array.

  iex> Solid.Filter.first([1, 2, 3])
  1
  iex> Solid.Filter.first([])
  nil
  iex> Solid.Filter.first("A string")
  "A"
  iex> Solid.Filter.first(5)
  nil
  """
  @spec first(any) :: any
  def first(input) when is_list(input), do: List.first(input)
  def first(input) when is_binary(input), do: String.first(input) || ""
  def first(_), do: nil

  @doc """
  Rounds a number down to the nearest whole number.
  Solid tries to convert the input to a number before the filter is applied.

  iex> Solid.Filter.floor(1.2)
  1
  iex> Solid.Filter.floor(2.0)
  2
  iex> Solid.Filter.floor("3.5")
  3
  """
  @spec floor(any) :: integer
  def floor(input) do
    if i = any_to_float(input) do
      i |> Float.floor() |> trunc()
    else
      input
    end
  end

  @doc """
  Removes all occurrences of nil from a list

  iex> Solid.Filter.compact([1, nil, 2, nil, 3])
  [1, 2, 3]
  """
  @spec compact(any) :: list | any
  def compact(input) when is_list(input), do: Enum.reject(input, &is_nil/1)
  def compact(input), do: input

  def compact(input, property) when is_list(input), do: Enum.reject(input, &(&1[property] == nil))
  def compact(input, _), do: input

  @doc """
  Concatenates (joins together) multiple arrays.
  The resulting array contains all the items from the input arrays.

  iex> Solid.Filter.concat([1, 2], [3, 4])
  [1, 2, 3, 4]
  """
  @spec concat(any, any) :: list | any
  def concat(input, list) when is_list(input) and is_list(list) do
    input ++ list
  end

  def concat(input, _), do: input

  @doc """
  Join a list of strings returning one String glued by `glue`

  iex> Solid.Filter.join(["a", "b", "c"])
  "a b c"
  iex> Solid.Filter.join(["a", "b", "c"], "-")
  "a-b-c"
  """
  @spec join(any, String.t()) :: String.t() | any
  def join(input, glue \\ " ")
  def join(input, glue) when is_list(input), do: Enum.join(input, glue)

  def join(input, glue) do
    case as_array(input) do
      [] -> input
      ary -> Enum.join(ary, glue)
    end
  end

  @doc """
  Returns the last item of an array.

  iex> Solid.Filter.last([1, 2, 3])
  3
  iex> Solid.Filter.last([])
  nil
  iex> Solid.Filter.last("A string")
  "g"
  iex> Solid.Filter.last(5)
  nil
  """
  @spec last(any) :: any
  def last(input) when is_list(input), do: List.last(input)
  def last(input) when is_binary(input), do: String.last(input) || ""
  def last(_), do: nil

  @doc """
  Removes all whitespaces (tabs, spaces, and newlines) from the beginning of a string.
  The filter does not affect spaces between words.

  iex> Solid.Filter.lstrip("          So much room for activities!          ")
  "So much room for activities!          "
  """
  @spec lstrip(any) :: String.t()
  def lstrip(input), do: input |> to_string() |> String.trim_leading()

  @doc """
  Split input string into an array of substrings separated by given pattern.

  iex> Solid.Filter.split("a b c", " ")
  ~w(a b c)
  iex> Solid.Filter.split("", " ")
  [""]
  """
  @spec split(any, String.t()) :: list(String.t())
  def split(input, pattern), do: input |> to_string() |> String.split(pattern)

  @doc """
  Removes leading and trailing whitespace and collapses consecutive whitespace to a single space.

  iex> Solid.Filter.squish("  foo   bar  \\n  baz  ")
  "foo bar baz"
  """
  @spec squish(any) :: String.t() | nil
  def squish(nil), do: nil

  def squish(input) do
    input
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  @doc """
  Map through a list of hashes accessing `property`

  iex> Solid.Filter.map([%{"a" => "A"}, %{"a" => 1}], "a")
  ["A", 1]
  """
  def map(input, property) do
    for i <- as_array(input), do: access_property(i, property)
  end

  @doc """
  Subtracts a number from another number.

  iex> Solid.Filter.minus(4, 2)
  2
  iex> Solid.Filter.minus(16, 4)
  12
  iex> Solid.Filter.minus(183.357, 12)
  171.357
  """
  @spec minus(any, any) :: number
  def minus(input, number) do
    a = any_to_float(input)
    b = any_to_float(number)

    if a && b do
      number_trunc(a - b)
    else
      input
    end
  end

  @doc """
  Subtracts a number from another number.

  iex> Solid.Filter.modulo(3, 2)
  1
  iex> Solid.Filter.modulo(24, 7)
  3
  iex> Solid.Filter.modulo(183.357, 12)
  3.357
  """
  @spec modulo(any, any) :: number
  def modulo(dividend, divisor) when is_integer(dividend) and is_integer(divisor) and divisor != 0 do
    Integer.mod(dividend, divisor)
  end

  def modulo(dividend, divisor) when is_integer(dividend) and is_integer(divisor), do: dividend

  def modulo(dividend, divisor) do
    a = any_to_float(dividend)
    b = any_to_float(divisor)

    cond do
      is_nil(a) or is_nil(b) ->
        dividend

      b == 0 ->
        dividend

      true ->
        a
        |> :math.fmod(b)
        |> Float.round(decimal_places(dividend))
    end
  end

  defp decimal_places(float) when is_float(float) do
    string = Float.to_string(float)
    {start, _} = :binary.match(string, ".")
    byte_size(string) - start - 1
  end

  defp decimal_places(_), do: 0

  @doc """
  Adds a number to another number.

  iex> Solid.Filter.plus(4, 2)
  6
  iex> Solid.Filter.plus(16, 4)
  20
  iex> Solid.Filter.plus("16", 4)
  20
  iex> Solid.Filter.plus(183.357, 12)
  195.357
  iex> Solid.Filter.plus("183.357", 12)
  195.357
  iex> Solid.Filter.plus("183.ABC357", 12)
  nil
  """
  @spec plus(number, number) :: number
  def plus(input, number) when is_number(input) do
    if y = any_to_float(number) do
      number_trunc(input + y)
    else
      input
    end
  end

  def plus(input, number) when is_binary(input) do
    if x = any_to_float(input) do
      x |> plus(number) |> number_trunc()
    end
  end

  def plus(input, number) do
    if y = any_to_float(number), do: y, else: input
  end

  @doc """
  Adds the specified string to the beginning of another string.

  iex> Solid.Filter.prepend("/index.html", "www.example.com")
  "www.example.com/index.html"
  """
  @spec prepend(any, any) :: String.t()
  def prepend(input, string), do: "#{string}#{input}"

  @doc """
  Removes every occurrence of the specified substring from a string.

  iex> Solid.Filter.remove("I strained to see the train through the rain", "rain")
  "I sted to see the t through the "
  """
  @spec remove(String.t(), String.t()) :: String.t()
  def remove(input, string) do
    input = to_string(input)
    string = to_string(string)
    String.replace(input, string, "")
  end

  @doc """
  Removes only the first occurrence of the specified substring from a string.

  iex> Solid.Filter.remove_first("I strained to see the train through the rain", "rain")
  "I sted to see the train through the rain"
  """
  @spec remove_first(String.t(), String.t()) :: String.t()
  def remove_first(input, string) do
    replace_first(input, string, "")
  end

  @doc """
  Removes only the last occurrence of the specified substring from a string.

  iex> Solid.Filter.remove_last("I strained to see the train through the rain", "rain")
  "I strained to see the train through the "
  """
  @spec remove_last(String.t(), String.t()) :: String.t()
  def remove_last(input, string) do
    replace_last(input, string, "")
  end

  @doc """
  Replaces every occurrence of an argument in a string with the second argument.

  iex> Solid.Filter.replace("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put your helmet on"
  """
  @spec replace(String.t(), String.t(), String.t()) :: String.t()
  def replace(input, string, replacement \\ "") do
    input = to_string(input)
    string = to_string(string)
    replacement = to_string(replacement)
    String.replace(input, string, replacement)
  end

  @doc """
  Replaces only the first occurrence of the first argument in a string with the second argument.

  iex> Solid.Filter.replace_first("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put my helmet on"
  """
  @spec replace_first(String.t(), String.t(), String.t()) :: String.t()
  def replace_first(input, string, replacement \\ "") do
    input = to_string(input)
    string = to_string(string)
    replacement = to_string(replacement)
    String.replace(input, string, replacement, global: false)
  end

  @doc """
  Replaces only the last occurrence of the first argument in a string with the second argument.

  iex> Solid.Filter.replace_last("Take my protein pills and put my helmet on", "my", "your")
  "Take my protein pills and put your helmet on"
  """
  @spec replace_last(String.t(), String.t(), String.t()) :: String.t()
  def replace_last(input, string, replacement \\ "") do
    input = to_string(input)
    string = to_string(string)
    replacement = to_string(replacement)

    case last_index(input, string) do
      nil ->
        input

      index ->
        {prefix, suffix} = String.split_at(input, index)
        prefix <> replace_first(suffix, string, replacement)
    end
  end

  defp last_index(input, string) do
    do_last_index(input, string, 0, nil)
  end

  defp do_last_index("", _string, _index, last), do: last

  defp do_last_index(input, string, index, last) do
    new_last =
      if String.starts_with?(input, string) do
        index
      else
        last
      end

    do_last_index(String.slice(input, 1..-1//1), string, index + 1, new_last)
  end

  @doc """
  Reverses the order of the items in an array. reverse cannot reverse a string.

  iex> Solid.Filter.reverse(["a", "b", "c"])
  ["c", "b", "a"]
  """
  @spec reverse(any) :: list | any
  def reverse(input) when is_list(input), do: Enum.reverse(input)
  def reverse(input) when is_map(input) and not is_struct(input), do: [input]
  def reverse(input), do: input

  @doc """
  Rounds an input number to the nearest integer or,
  if a number is specified as an argument, to that number of decimal places.

  iex> Solid.Filter.round(1.2)
  1
  iex> Solid.Filter.round(2.7)
  3
  iex> Solid.Filter.round(183.357, 2)
  183.36
  """
  @spec round(any) :: number | any
  def round(input, precision \\ nil)

  def round(input, nil) do
    if i = any_to_float(input), do: Kernel.round(i), else: input
  end

  def round(input, precision) do
    i = any_to_float(input)
    p = any_to_float(precision)

    if i && p do
      factor = :math.pow(10, p)
      Kernel.round(i * factor) / factor
    else
      input
    end
  end

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from the right side of a string.

  iex> Solid.Filter.rstrip("          So much room for activities!          ")
  "          So much room for activities!"
  """
  @spec rstrip(String.t()) :: String.t()
  def rstrip(input), do: input |> to_string() |> String.trim_trailing()

  @doc """
  Returns the number of characters in a string or the number of items in an array.

  iex> Solid.Filter.size("Ground control to Major Tom.")
  28
  iex> Solid.Filter.size(~w(ground control to Major Tom.))
  5
  """
  @spec size(String.t() | list | map) :: non_neg_integer
  def size(input) when is_list(input), do: length(input)
  def size(input) when is_struct(input), do: input |> Map.from_struct() |> Enum.count()
  def size(input) when is_map(input), do: Enum.count(input)
  def size(input) when is_bitstring(input), do: String.length(input)
  def size(_input), do: 0

  @doc """
  Returns a substring of 1 character beginning at the index specified by the argument passed in.
  An optional second argument specifies the length of the substring to be returned.

  String indices are numbered starting from 0.

  iex> Solid.Filter.slice("Liquid", 0)
  "L"

  iex> Solid.Filter.slice("Liquid", 2)
  "q"

  iex> Solid.Filter.slice("Liquid", 2, 5)
  "quid"
  iex> Solid.Filter.slice("Liquid", -3, 2)
  "ui"
  """
  @spec slice(String.t() | list(), integer, non_neg_integer | nil) :: String.t() | list | any
  def slice(input, offset, length \\ nil)

  def slice(input, offset, nil) when is_binary(input), do: input |> to_string() |> String.at(offset)

  def slice(input, offset, length) when is_binary(input), do: input |> to_string() |> String.slice(offset, length)

  def slice(input, _offset, nil) when is_list(input), do: input
  def slice(input, offset, length) when is_list(input), do: Enum.slice(input, offset, length)
  def slice(input, _, _), do: input

  @doc """
  Sorts items in an array. The order of the sorted array is case-sensitive.

  iex> Solid.Filter.sort(~w(zebra octopus giraffe SallySnake))
  ~w(SallySnake giraffe octopus zebra)

  iex> Solid.Filter.sort([%{"a" => 2}, %{"a" => 1}], "a")
  [%{"a" => 1}, %{"a" => 2}]
  """
  @spec sort(any) :: list | any
  @spec sort(any, any) :: list | any
  def sort(input) when is_list(input), do: Enum.sort(input)
  def sort(input), do: input

  def sort(input, property) when is_list(input) do
    Enum.sort_by(input, &access_property(&1, property), &nil_safe_lte?/2)
  rescue
    _ -> input
  end

  def sort(input, _), do: input

  @doc """
  Sorts items in an array in case-insensitive order.

  iex> Solid.Filter.sort_natural(~w(zebra octopus giraffe SallySnake))
  ~w(giraffe octopus SallySnake zebra)
  """
  @spec sort_natural(any) :: list | any
  @spec sort_natural(any, any) :: list | any
  def sort_natural(input) when is_list(input) do
    Enum.sort(input, &(String.downcase(to_string(&1)) <= String.downcase(to_string(&2))))
  end

  def sort_natural(input), do: input

  def sort_natural(input, property) when is_list(input) do
    Enum.sort_by(input, &access_property(&1, property), &nil_safe_casey_lte?/2)
  rescue
    _ -> input
  end

  def sort_natural(input, _), do: input

  defp access_property(item, property) when is_map(item), do: item[property]
  defp access_property(_, _), do: nil

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from both the left and right side of a string.
  It does not affect spaces between words.

  iex> Solid.Filter.strip("          So much room for activities!          ")
  "So much room for activities!"
  """
  @spec strip(String.t()) :: String.t()
  def strip(input), do: input |> to_string() |> String.trim()

  @doc """
  Multiplies a number by another number.

  iex> Solid.Filter.times(3, 2)
  6
  iex> Solid.Filter.times(24, 7)
  168
  iex> Solid.Filter.times(183.357, 12)
  2200.284
  """
  @spec times(any, any) :: number
  def times(input, operand) do
    a = any_to_float(input)
    b = any_to_float(operand)

    if a && b do
      number_trunc(a * b)
    else
      input
    end
  end

  @doc """
  truncate shortens a string down to the number of characters passed as a parameter.
  If the number of characters specified is less than the length of the string, an ellipsis (…) is appended to the string
  and is included in the character count.

  iex> Solid.Filter.truncate("Ground control to Major Tom.", 20)
  "Ground control to..."

  # Custom ellipsis

  truncate takes an optional second parameter that specifies the sequence of characters to be appended to the truncated string.
  By default this is an ellipsis (…), but you can specify a different sequence.

  The length of the second parameter counts against the number of characters specified by the first parameter.
  For example, if you want to truncate a string to exactly 10 characters, and use a 3-character ellipsis,
  use 13 for the first parameter of truncate, since the ellipsis counts as 3 characters.

  iex> Solid.Filter.truncate("Ground control to Major Tom.", 25, ", and so on")
  "Ground control, and so on"

  # No ellipsis

  You can truncate to the exact number of characters specified by the first parameter
  and show no trailing characters by passing a blank string as the second parameter:

  iex> Solid.Filter.truncate("Ground control to Major Tom.", 20, "")
  "Ground control to Ma"
  """
  @spec truncate(String.t(), non_neg_integer, String.t()) :: String.t()
  def truncate(input, length, ellipsis \\ "...") do
    if is_bitstring(input) and String.length(input) > length do
      length = max(0, length - String.length(ellipsis))
      slice(input, 0, length) <> ellipsis
    else
      input
    end
  end

  @doc """
  Shortens a string down to the number of words passed as the argument.
  If the specified number of words is less than the number of words in the string, an ellipsis (…) is appended to the string.

  iex> Solid.Filter.truncatewords("Ground control to Major Tom.", 3)
  "Ground control to..."

  # Custom ellipsis

  `truncatewords` takes an optional second parameter that specifies the sequence of characters to be appended to the truncated string.
  By default this is an ellipsis (…), but you can specify a different sequence.

  iex> Solid.Filter.truncatewords("Ground control to Major Tom.", 3, "--")
  "Ground control to--"

  # No ellipsis

  You can avoid showing trailing characters by passing a blank string as the second parameter:

  iex> Solid.Filter.truncatewords("Ground control to Major Tom.", 3, "")
  "Ground control to"
  """
  @spec truncatewords(nil | String.t(), non_neg_integer, String.t()) :: String.t()
  def truncatewords(input, max_words, ellipsis \\ "...")
  def truncatewords(nil, _max_words, _ellipsis), do: ""

  def truncatewords(input, max_words, ellipsis) do
    words = input |> to_string() |> String.split(" ", trim: true)

    if length(words) > max_words do
      words
      |> Enum.take(max_words)
      |> Enum.intersperse(" ")
      |> Enum.join()
      |> Kernel.<>(ellipsis)
    else
      input
    end
  end

  @doc """
  Removes any duplicate elements in an array.

  Output
  iex> Solid.Filter.uniq(~w(ants bugs bees bugs ants))
  ~w(ants bugs bees)

  iex> Solid.Filter.uniq([%{"a" => 1}, %{"a" => 1}, %{"a" => 2}], "a")
  [%{"a" => 1}, %{"a" => 2}]
  """
  @spec uniq(any) :: list | any
  @spec uniq(any, any) :: list | any
  def uniq(input) when is_list(input), do: Enum.uniq(input)
  def uniq(input), do: input

  def uniq(input, property) when is_list(input) do
    Enum.uniq_by(input, &access_property(&1, property))
  rescue
    _ -> input
  end

  def uniq(input, _), do: input

  @doc """
  Removes any newline characters (line breaks) from a string.

  Output
  iex> Solid.Filter.strip_newlines("Test \\ntext\\r\\n with line breaks.")
  "Test text with line breaks."

  iex> Solid.Filter.strip_newlines([[["Test \\ntext\\r\\n with "] | "line breaks."]])
  "Test text with line breaks."
  """
  @spec strip_newlines(iodata()) :: String.t()
  def strip_newlines(iodata) do
    binary = to_string(iodata)
    pattern = :binary.compile_pattern(["\r\n", "\n"])
    String.replace(binary, pattern, "")
  end

  @doc """
  Replaces every newline in a string with an HTML line break (<br />).

  Output
  iex> Solid.Filter.newline_to_br("Test \\ntext\\r\\n with line breaks.")
  "Test <br />\\ntext<br />\\r\\n with line breaks."

  iex> Solid.Filter.newline_to_br([[["Test \\ntext\\r\\n with "] | "line breaks."]])
  "Test <br />\\ntext<br />\\r\\n with line breaks."
  """
  @spec newline_to_br(iodata()) :: String.t()
  def newline_to_br(iodata) do
    binary = to_string(iodata)
    pattern = :binary.compile_pattern(["\r\n", "\n"])
    String.replace(binary, pattern, fn x -> "<br />#{x}" end)
  end

  @doc """
  Creates an array including only the objects with a given property value,
  or any truthy value by default.

  Output
  iex> input = [
  ...>   %{"id" => 1, "type" => "kitchen"},
  ...>   %{"id" => 2, "type" => "bath"},
  ...>   %{"id" => 3, "type" => "kitchen"}
  ...> ]
  iex> Solid.Filter.where(input, "type", "kitchen")
  [%{"id" => 1, "type" => "kitchen"}, %{"id" => 3, "type" => "kitchen"}]

  iex> input = [
  ...>   %{"id" => 1, "available" => true},
  ...>   %{"id" => 2, "available" => false},
  ...>   %{"id" => 3, "available" => true}
  ...> ]
  iex> Solid.Filter.where(input, "available")
  [%{"id" => 1, "available" => true}, %{"id" => 3, "available" => true}]
  """
  @spec where(any, any) :: list
  @spec where(any, any, any) :: list
  def where(input, key, value), do: filter_array(input, key, value, [], &Enum.filter/2)
  def where(input, key), do: filter_array(input, key, nil, [], &Enum.filter/2)

  @doc """
  Filters an array to exclude items with a specific property value.

  iex> input = [
  ...>   %{"id" => 1, "type" => "kitchen"},
  ...>   %{"id" => 2, "type" => "bath"},
  ...>   %{"id" => 3, "type" => "kitchen"}
  ...> ]
  iex> Solid.Filter.reject(input, "type", "kitchen")
  [%{"id" => 2, "type" => "bath"}]
  """
  @spec reject(any, any) :: list
  @spec reject(any, any, any) :: list
  def reject(input, key, value), do: filter_array(input, key, value, [], &Enum.reject/2)
  def reject(input, key), do: filter_array(input, key, nil, [], &Enum.reject/2)

  @doc """
  Tests if any item in an array has a specific property value.

  iex> input = [%{"type" => "kitchen"}, %{"type" => "bath"}]
  iex> Solid.Filter.has(input, "type", "bath")
  true
  iex> Solid.Filter.has(input, "type", "garage")
  false
  """
  @spec has(any, any) :: boolean
  @spec has(any, any, any) :: boolean
  def has(input, key, value), do: filter_array(input, key, value, false, &Enum.any?/2)
  def has(input, key), do: filter_array(input, key, nil, false, &Enum.any?/2)

  @doc """
  Returns the first item in an array with a specific property value.

  iex> input = [%{"type" => "kitchen"}, %{"type" => "bath"}]
  iex> Solid.Filter.find(input, "type", "bath")
  %{"type" => "bath"}
  """
  @spec find(any, any) :: any
  @spec find(any, any, any) :: any
  def find(input, key, value), do: filter_array(input, key, value, nil, &Enum.find/2)
  def find(input, key), do: filter_array(input, key, nil, nil, &Enum.find/2)

  @doc """
  Returns the index of the first item in an array with a specific property value.

  iex> input = [%{"type" => "kitchen"}, %{"type" => "bath"}]
  iex> Solid.Filter.find_index(input, "type", "bath")
  1
  """
  @spec find_index(any, any) :: non_neg_integer | nil
  @spec find_index(any, any, any) :: non_neg_integer | nil
  def find_index(input, key, value), do: filter_array(input, key, value, nil, &Enum.find_index/2)
  def find_index(input, key), do: filter_array(input, key, nil, nil, &Enum.find_index/2)

  @doc """
  Returns the sum of all elements in an array.

  iex> Solid.Filter.sum([1, 2, 3])
  6
  iex> Solid.Filter.sum([%{"price" => 1}, %{"price" => 2}], "price")
  3
  iex> Solid.Filter.sum([])
  0
  """
  @spec sum(any) :: number
  @spec sum(any, any) :: number
  def sum(input, property \\ nil)

  def sum(input, property) do
    input
    |> as_array()
    |> Enum.reduce(0, fn item, acc ->
      value =
        cond do
          is_nil(property) -> item
          is_map(item) -> item[property]
          true -> 0
        end

      acc + (any_to_float(value) || 0)
    end)
    |> number_trunc()
  end

  @doc """
  Removes any HTML tags from a string.

  This mimics the regex based approach of the ruby library.

  Output
  iex> Solid.Filter.strip_html("Have <em>you</em> read <strong>Ulysses</strong>?")
  "Have you read Ulysses?"
  """
  @html_blocks ~r{(<script.*?</script>)|(<!--.*?-->)|(<style.*?</style>)}m
  @html_tags ~r|<.*?>|m
  @spec strip_html(iodata()) :: String.t()
  def strip_html(iodata) do
    iodata
    |> to_string()
    |> String.replace(@html_blocks, "")
    |> String.replace(@html_tags, "")
  end

  @doc """
  URL encodes the string.

  Output
  iex> Solid.Filter.url_encode("john@liquid.com")
  "john%40liquid.com"

  iex> Solid.Filter.url_encode("Tetsuro Takara")
  "Tetsuro+Takara"
  """
  def url_encode(iodata) do
    iodata
    |> to_string()
    |> URI.encode_www_form()
  end

  @doc """
  URL decodes the string.

  Output
  iex> Solid.Filter.url_decode("%27Stop%21%27+said+Fred")
  "'Stop!' said Fred"
  """
  def url_decode(iodata) do
    iodata
    |> to_string()
    |> URI.decode_www_form()
  end

  @doc """
  HTML encodes the string.

  Output
  iex> Solid.Filter.escape("Have you read 'James & the Giant Peach'?")
  "Have you read &#39;James &amp; the Giant Peach&#39;?"
  """
  @spec escape(iodata()) :: String.t()
  def escape(iodata) do
    iodata
    |> to_string()
    |> Solid.HTML.html_escape()
  end

  @doc """
  HTML encodes the string without encoding already encoded characters again.

  This mimics the regex based approach of the ruby library.

  Output
  "1 &lt; 2 &amp; 3"

  iex> Solid.Filter.escape_once("1 &lt; 2 &amp; 3")
  "1 &lt; 2 &amp; 3"
  """
  @escape_once_regex ~r{["><']|&(?!([a-zA-Z]+|(#\d+));)}
  @spec escape_once(iodata()) :: String.t()
  def escape_once(iodata) do
    iodata
    |> to_string()
    |> String.replace(@escape_once_regex, &Solid.HTML.replacements/1)
  end

  @doc """
  Encodes a string to Base64 format.

  iex> Solid.Filter.base64_encode("apples")
  "YXBwbGVz"
  """
  @spec base64_encode(iodata()) :: String.t()
  def base64_encode(iodata) do
    iodata
    |> to_string()
    |> Base.encode64()
  end

  @doc """
  Decodes a string in Base64 format.

  iex> Solid.Filter.base64_decode("YXBwbGVz")
  "apples"
  iex> Solid.Filter.base64_decode("not-valid")
  "not-valid"
  """
  @spec base64_decode(iodata()) :: String.t()
  def base64_decode(iodata) do
    input = to_string(iodata)

    case Base.decode64(input) do
      {:ok, decoded} -> decoded
      :error -> input
    end
  end

  @doc """
  Encodes a string to URL-safe Base64 format.

  iex> Solid.Filter.base64_url_safe_encode("apples")
  "YXBwbGVz"
  """
  @spec base64_url_safe_encode(iodata()) :: String.t()
  def base64_url_safe_encode(iodata) do
    iodata
    |> to_string()
    |> Base.url_encode64()
  end

  @doc """
  Decodes a string in URL-safe Base64 format.

  iex> Solid.Filter.base64_url_safe_decode("YXBwbGVz")
  "apples"
  iex> Solid.Filter.base64_url_safe_decode("not-valid")
  "not-valid"
  """
  @spec base64_url_safe_decode(iodata()) :: String.t()
  def base64_url_safe_decode(iodata) do
    input = to_string(iodata)

    case Base.url_decode64(input) do
      {:ok, decoded} -> decoded
      :error -> input
    end
  end
end
