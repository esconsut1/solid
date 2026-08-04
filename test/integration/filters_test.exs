defmodule Solid.Integration.FiltersTest do
  use ExUnit.Case, async: true

  import Solid.Helpers

  alias Solid.UndefinedFilterError
  alias Solid.UndefinedVariableError

  test "multiple filters" do
    assert render("Text {{ key | default: 1 | upcase }} !", %{"key" => "abc"}) == "Text ABC !"
  end

  test "upcase filter" do
    assert render("Text {{ key | upcase }} !", %{"key" => "abc"}) == "Text ABC !"
  end

  test "default filter with default integer" do
    assert render("Number {{ key | default: 456 }} !") ==
             "Number 456 !"
  end

  test "default filter with default variable" do
    assert render("Number {{ key | default: other_key }} !", %{"other_key" => 456}) ==
             "Number 456 !"
  end

  test "default filter with strict_variables" do
    assert render("Number {{ key | default: other_key }} !", %{}, strict_variables: true) ==
             {:error,
              [
                %UndefinedVariableError{variable: ["key"]},
                %UndefinedVariableError{variable: ["other_key"]}
              ], "Number  !"}
  end

  test "strict filters" do
    assert render("Number {{ key | filter }} !", %{"key" => "val"}, strict_filters: true) ==
             {:error,
              [
                %UndefinedFilterError{filter: "filter"}
              ], "Number val !"}
  end

  test "default filter with default string" do
    assert render("Number {{ key | default: \"456\" }} !", %{}) == "Number 456 !"
  end

  test "default filter with default float" do
    assert render("Number {{ key | default: 44.5 }} !", %{}) == "Number 44.5 !"
  end

  test "default filter with nil" do
    assert render("Number {{ nil | default: 456 }} !", %{"nil" => 123}) == "Number 456 !"
  end

  test "default filter with an integer" do
    assert render("Number {{ 123 | default: 456 }} !", %{}) == "Number 123 !"
  end

  test "default filter with a negative integer" do
    assert render("Number {{ 123 | plus: -123}} !", %{}) == "Number 0 !"
  end

  test "replace" do
    assert render(
             "{{ \"Take my protein pills and put my helmet on\" | replace: \"my\", \"your\" }}",
             %{}
           ) ==
             "Take your protein pills and put your helmet on"
  end

  test "concat" do
    assert render(
             """
             {% assign fruits = "apples, oranges" | split: ", " %}
             {% assign vegetables = "kale, cucumbers" | split: ", " %}
             {% assign everything = fruits | concat: vegetables %}
             {% for item in everything %}
             - {{ item }}
             {% endfor %}
             """,
             %{}
           ) == "\n\n\n\n- apples\n\n- oranges\n\n- kale\n\n- cucumbers\n\n"
  end

  test "replace_last" do
    assert render("{{ \"mmmmm\" | replace_last: \"mmm\", \"eww\"  }}", %{}) == "mmeww"

    assert render("{{ \"̀etudes for elixir\" | replace_last: \"elixir\", \"erlang\" }}", %{}) ==
             "̀etudes for erlang"
  end

  test "default with allow_false" do
    assert render("{{ false | default: \"fallback\", allow_false: true }}", %{}) == "false"
    assert render("{{ false | default: \"fallback\" }}", %{}) == "fallback"
  end

  test "squish filter" do
    assert render("{{ \"  foo   bar  \" | squish }}", %{}) == "foo bar"
  end

  test "sum filter" do
    assert render("{{ numbers | sum }}", %{"numbers" => [1, 2, 3]}) == "6"
    assert render("{{ products | sum: \"price\" }}", %{"products" => [%{"price" => 1}, %{"price" => 2}]}) == "3"
  end

  test "reject has find find_index" do
    products = [
      %{"name" => "Sink", "type" => "kitchen", "available" => true},
      %{"name" => "Tub", "type" => "bath", "available" => false}
    ]

    assert render("{{ products | has: \"type\", \"bath\" }}", %{"products" => products}) == "true"
    assert render("{{ products | find_index: \"type\", \"bath\" }}", %{"products" => products}) == "1"

    assert render("{{ products | reject: \"type\", \"kitchen\" | map: \"name\" | join: \",\" }}", %{
             "products" => products
           }) ==
             "Tub"
  end

  test "soft fail on type mismatch returns input" do
    assert render("{{ \"not-valid\" | base64_decode }}", %{}) == "not-valid"
    assert render("{{ \"not-valid\" | base64_url_safe_decode }}", %{}) == "not-valid"
    assert render("{{ \"abc\" | concat: \"def\" }}", %{}) == "abc"
    assert render("{{ 5 | reverse }}", %{}) == "5"
  end
end
