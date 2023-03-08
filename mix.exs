defmodule Solid.Mixfile do
  use Mix.Project

  @source_url "https://github.com/edgurgel/solid"
  @version "0.14.1"

  def project do
    [
      app: :solid,
      version: @version,
      elixir: "~> 1.14.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      name: "solid",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application, do: []

  defp deps do
    [
      {:nimble_parsec, "~> 1.2"},
      {:jason, "~> 1.4", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      description: "Liquid Template engine",
      maintainers: ["Eduardo Gurgel Pinho"],
      licenses: ["MIT"],
      links: %{"Github" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        "CONTRIBUTING.md": [title: "Contributing"],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
