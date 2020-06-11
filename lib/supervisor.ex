defmodule GPSupervisor do
  use Supervisor

 def start_link(numNodes) do
  Supervisor.start_link(__MODULE__,[numNodes,self()], name: __MODULE__)
 end

   
 def init(args) do
  children = Enum.map(1..hd(args), fn(x) ->
    worker(GPSERVER, [x], [id: x, restart: :temporary])
  end)
  Supervisor.init(children, strategy: :one_for_one)
 end
end
