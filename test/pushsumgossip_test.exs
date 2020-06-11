defmodule PUSHSUMGOSSIPTest do
  use ExUnit.Case
  doctest GOSSIP

  test "greets the world" do
    IO.inspect(SUPERVISOR.start_link(10), limit: :infinity)
    #assert PUSHSUMGOSSIP.hello() == :world
  end
end
