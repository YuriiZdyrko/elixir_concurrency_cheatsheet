defmodule PracticeTest do
  use ExUnit.Case
  doctest Practice

  test "greets the world" do
    assert Practice.hello() == :world
  end
end
