defmodule ExNodeTest do
  use ExUnit.Case
  doctest ExNode

  test "greets the world" do
    assert ExNode.hello() == :world
  end
end
