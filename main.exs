defmodule MAIN do
  [num,topology,algorithm] =Enum.map(System.argv, (fn(x) -> x end))
  num = String.to_integer(num)
  nodes = case topology do
    "3Dtorus" -> round(:math.pow(Float.ceil(:math.pow(num,(1/3))),3))
    "honeycomb"->trunc(Float.ceil(num/14)*14)
    "honeycombR"->trunc(Float.ceil(num/14)*14)
    _ -> num
  end
  GPSupervisor.start_link(nodes)
  Topology.beginTopology(topology,nodes,algorithm)
  case algorithm do
    "gossip" -> GPSERVER.beginGossip("Hello World",System.os_time(:millisecond),nodes)
    "push-sum" ->  GPSERVER.startPushSum(nodes,System.monotonic_time(:millisecond))
    _ -> IO.puts "No such algorithm exists"
    System.halt(1)
  end
  Process.flag(:trap_exit, true)
end
