defmodule GPSERVER do
  use GenServer


  def start_link(num) do
    GenServer.start_link(__MODULE__,[0,[],num,1,""], name: String.to_atom("n_"<>Integer.to_string(num)))
  end

  def init(args) do
    Process.flag(:trap_exit, true)
    {:ok, args}
  end

  def handle_cast({:updateCount,msg}, state) do
    [count,blist,s,w,_]=state
    state=[count+1,blist,s,w,msg]
    {:noreply, state}
  end
   
  def handle_cast({:neighboursList,list}, state) do
    [count,glist,s,w,msg]=state
    state=[count,list++glist,s,w,msg]
    {:noreply, state}
  end
   
  def handle_cast({:updatePushSum,updatedS,updatedW,count},state) do
    [_,blist,_,_,msg]=state
    state=[count,blist,updatedS,updatedW,msg]
    {:noreply, state}
  end

  def handle_cast({:neigh,msg,startT,num1},state) do
    neighNode=getAliveNeighbour((Enum.at(state,1)))
    if(neighNode != :false) do
      spawn fn -> GenServer.cast(neighNode,{:received,msg,startT,num1}) end
      GenServer.cast(self(),{:neigh,msg,startT,num1})
    end
      {:noreply,state}
  end

  def handle_cast({:received,msg,num1,startT},state) do
    if(Enum.at(state,0)>=10) do
      stopExecution(num1,startT,self())
    else
     if(Enum.at(state,0)==0) do
        GenServer.cast(self(),{:neigh,msg,startT,num1})
     end
    end
    [count,list,s,w,_]=state
    {:noreply,[count+1,list,s,w,msg],state}
  end

  def handle_call({:getState},_from,state) do
    {:reply,state,state}
  end
  def handle_call({:neighboursList},_from,state) do
    {:reply,Enum.at(state,1),state}
  end
  def handle_call({:converge,startT},_from,_) do
    endT= System.os_time(:millisecond)
    time = endT-startT
    IO.puts("Convergence time: #{inspect time}ms")
    System.halt(1)
  end

  def handle_call({:kill,startT,_tcount,_num1,prevstate},_from,_) do
    endT = System.monotonic_time(:millisecond)
    time = endT-startT
    IO.puts("Convergence time: #{inspect time}ms")
    :ets.insert(:table,{"deadProcess",0})
    :ets.insert(:table,{"ProcessList",[]})
    IO.puts("The ratio of convergence S/W: #{inspect (Enum.at(prevstate,2)/Enum.at(prevstate,3))}")
    System.halt(1)
  end

  def updateNeighbours(id,list) do
    GenServer.cast(id,{:neighboursList, list})
  end

  def getNeighbours(id) do
    GenServer.call(id,{:neighboursList})
  end

  def getState(pid) do
    GenServer.call(pid,{:getState})
  end

  def stopExecution(num1,startT,state,pid) do
    [{_,list}]=:ets.lookup(:table,"ProcessList")
    if(Enum.any?(list,fn x-> x==pid end) == :false) do
      :ets.insert(:table,{"ProcessList",[pid]++list})
      :ets.update_counter(:table,"deadProcess",{2,1})
    end
    [{_,tcount}]=:ets.lookup(:table,"deadProcess")
    [{_,table1}]=:ets.lookup(:table,"Algorithm")
    percent = if(table1 == "push-sum") do
      [{_,name}]=:ets.lookup(:table,"Topology")
      case name do
        "line" -> 0.9
        "rand2D" -> 0.75
        "honeycomb"-> 0.75
         "honeycombR"->0.75
        _->0.8
       end
    else
      0.9
    end
    #IO.puts percent
    if(tcount >= trunc(num1*percent)) do  
      GenServer.call(:n_0,{:kill,startT,tcount,num1,state})
    end
  end

  ## Gossip Algorithm ##

  def beginGossip(msg,startT,num1) do
    psname=String.to_atom("n_"<>Integer.to_string(:rand.uniform(num1)))
    GenServer.cast(psname,{:received,msg,num1,startT})
    waitfunc(startT)
  end

  def waitfunc(startT) do
    endT = System.os_time(:millisecond)
    time = endT- startT
    if(time<=600000) do waitfunc(startT)
    else
      IO.puts "System has terminated after 10 min"
      System.halt(1)
    end
  end

  def stopExecution(num1,startT,pid) do
    [{_,list}]=:ets.lookup(:table,"ProcessList")
    if(Enum.any?(list,fn x-> x==pid end) == :false) do
      :ets.insert(:table,{"ProcessList",[pid]++list})
      :ets.update_counter(:table,"deadProcess",{2,1})
    end
    [{_,tcount}]=:ets.lookup(:table,"deadProcess")
    #IO.inspect tcount
      if(tcount >= trunc(num1*0.9)) do
        GenServer.call(:n_0,{:converge,startT})
      end
  end

  def getAliveNeighbour(list) do
    if(Enum.empty?(list)) do
      :false
    else
      neighbourNode=Enum.random(list)
      pid = String.to_atom(neighbourNode)
      [{_,nlist}]=:ets.lookup(:table,"ProcessList")
      if(Enum.any?(nlist,fn x-> x==pid end) != :false) do
        getAliveNeighbour(List.delete(list,neighbourNode))
      else String.to_atom(neighbourNode) end
    end
  end

  ## PUSH-SUM Algorithm  ##

  def startPushSum(num1,startT) do
    IO.puts "Push-sum started for #{num1} nodes"
    Enum.map(1..num1, fn(x)->
      psname = String.to_atom("n_"<>Integer.to_string(x))
      propogatePS(psname,0,0,num1,startT)
    end)
  end

  def propogatePS(psname,s,w,num1,startT) do
    state = getState(psname)
    oldS=Enum.at(state,2)
    oldW=Enum.at(state,3)
    count=Enum.at(state,0)
    updatedS = (s+oldS)
    updatedW = (w+oldW)
    diff = abs((updatedS/updatedW) - (oldS/oldW))
    neighNode = findPSNeighbours(Enum.at(state,1))

    if(count != -1) do
      ncount = checkCounter(diff,num1,count,startT,state,psname)
        GenServer.cast(psname,{:updatePushSum,updatedS/2,updatedW/2,ncount})
    end
      if(neighNode != :false) do
        val1 = if(count != -1) do updatedS/2 else oldS/2 end
        val2 = if(count != -1) do updatedW/2 else oldW/2 end
        #IO.puts("From #{inspect psname} to #{inspect neighNode}")
        spawn fn -> propogatePS(neighNode,val1,val2, num1, startT) end
        Process.sleep(100)
      else
        stopExecution(num1,startT,state,psname)
      end
  end

  def checkCounter(diff,num1,count,startT,state,psname) do
    if(diff < :math.pow(10,-10) && (count==2)) do
      #:ets.update_counter(:table,"deadProcess",{2,1})
      stopExecution(num1,startT,state,psname)
      -1
    else
      if(diff >= :math.pow(10,-10)) do 0 else count+1 end
    end
  end

  def findPSNeighbours(list) do
    if(Enum.empty?(list)) do
      :false
    else
      neighbour = String.to_atom(Enum.random(list))
      st = getState(neighbour)
      if(Enum.at(st,0)==-1) do
        findPSNeighbours(List.delete(list,Atom.to_string(neighbour)))
      else
        neighbour
      end
    end
  end
end
