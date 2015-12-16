defmodule Gallery.Mixfile do
  use Mix.Project

  def project do
    [ app: :gallery,
      version: "1.0.0",
      elixir: "~> 1.1.0",
      deps: deps ]
  end

  def application do
    [ mod: { Gallery, [] },
      applications: [:cowboy] ]
  end

  defp deps do
    [{:cowboy, github: "extend/cowboy", tag: :"1.0.4"},
     {:amnesia, github: "meh/amnesia", tag: :"v0.2.0"},
     {:erl_img, github: "evanmiller/erl_img"}]
  end
end
