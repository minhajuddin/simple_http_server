defmodule SimpleHTTPServerTest do
  use ExUnit.Case
  doctest SimpleHTTPServer

  test "greets the world" do
    assert SimpleHTTPServer.hello() == :world
  end
end
