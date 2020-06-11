defmodule Topology do
    def beginTopology(newTopology,num,algorithm) do
      table = :ets.new(:table, [:named_table,:public])
      case algorithm do
        "gossip" -> :ets.insert(table,{"Algorithm","gossip"})
        "push-sum" -> :ets.insert(table,{"Algorithm","push-sum"})
      end
      case newTopology do
        "3Dtorus"->torus3DTopology(num)
        :ets.insert(table,{"Topology","3Dtorus"})
        "full" ->fullTopology(num)
        :ets.insert(table,{"Topology","full"})
        "rand2D" ->rand2DTopology(num)
        :ets.insert(table,{"Topology","rand2D"})
        "line" -> lineTopology(num)
        :ets.insert(table,{"Topology","line"})
        "honeycomb"->honeyComb(num)
        :ets.insert(table,{"Topology","honeycomb"})
        "honeycombR"->honeyCombR(num)
        :ets.insert(table,{"Topology","honeycombR"})
        _ -> IO.puts "Incorrect Topology"
      end
      #IO.inspect Enum.map(1..num, fn(x) -> GPSERVER.getNeighbours(String.to_atom("n_"<>Integer.to_string(x))) end)
      :ets.insert(table,{"deadProcess",0})
      :ets.insert(table,{"ProcessList",[]})
      GPSERVER.start_link(0)
    end
   
      ### Line Topology ###

    def lineTopology(num) do
      Enum.each(1..num, fn(x) ->
        neighbour = cond do
          x==1 ->
            ["n_"<>Integer.to_string(x+1)]
          x==num ->
            ["n_"<>Integer.to_string(x-1)]
          true->
            [("n_"<>Integer.to_string(x-1)) , ("n_"<>Integer.to_string(x+1))]
          end
          GPSERVER.updateNeighbours(String.to_atom("n_"<>Integer.to_string(x)), neighbour)
      end)
    end

      ### full Topology ###

    def fullTopology(num) do
      list=Enum.map(1..num, fn(x)-> "n_"<>Integer.to_string(x) end)
      Enum.each(1..num, fn(x)->
        GPSERVER.updateNeighbours(String.to_atom("n_"<>Integer.to_string(x)), List.delete(list,"n_"<>Integer.to_string(x))) end)
    end

   
      ### 3Dtorus Topology ###

    def torus3DTopology(num) do
      cubeRoot = round(Float.ceil(:math.pow(num,(1/3))))
      Enum.each(1..num, fn x->
        neigh1 = if(x+1 <= num && rem(x,cubeRoot) != 0 ) do x+1 else x+1-cubeRoot  end
        neigh2 = if(rem(x,cubeRoot*cubeRoot) != 0 && cubeRoot*cubeRoot - cubeRoot >= rem(x,(cubeRoot*cubeRoot))) do x+ cubeRoot else  x-(cubeRoot-1)*cubeRoot end
        neigh3 = if(x+ cubeRoot*cubeRoot <= num) do x+ cubeRoot*cubeRoot else x-(cubeRoot-1)*cubeRoot*cubeRoot  end
        neigh4 = if(x-1 >= 1 && rem(x-1,cubeRoot) != 0) do x-1  else x+(cubeRoot-1) end
        neigh5 = if((cubeRoot*cubeRoot - cubeRoot*(cubeRoot-1)) < rem(x-1,(cubeRoot*cubeRoot)) + 1) do x- cubeRoot else x+(cubeRoot-1)*cubeRoot end
        neigh6 = if(x- cubeRoot*cubeRoot >= 1) do x- cubeRoot*cubeRoot else x+(cubeRoot-1)*cubeRoot*cubeRoot end
        list = [ neigh1, neigh2, neigh3, neigh4,neigh5,neigh6]
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn x->
          pname= "n_"<>Integer.to_string(x)
          pname
        end)
        #IO.inspect list
        GPSERVER.updateNeighbours(String.to_atom("n_"<>Integer.to_string(x)), list)
      end)
    end

    ###ran2D Topology ###

    def rand2DTopology(num) do
      map = Map.new()
      dividor = 100000 
      map =Enum.reduce(1..num,map, fn x,acc->
        node = String.to_atom("n_"<>Integer.to_string(x))
        coord= {(Enum.random(0..1000*10)/dividor),(Enum.random(0..1000*10)/dividor)}
        Map.put(acc,node,coord)
      end)
      #IO.inspect is_map(map)
      get2D(map)
    end
    defp get2D(list) do #TODO list of empty neighbours
      Map.keys(list)
      |> Enum.each(fn(x)->
        {refx, refy} = Map.fetch!(list,x)
        temp = Map.delete(list,x)
        keys = Map.keys(temp)
        Enum.each(keys, fn(y) ->
          {coorx,coory} = Map.fetch!(temp,y)
          if(:math.sqrt(:math.pow((refx-coorx),2) + :math.pow((refy-coory),2)) < 0.1) do
            GPSERVER.updateNeighbours(x, [Atom.to_string(y)])
          end
        end)
      end)
    end
### honeycomb Topology ###

def honeyComb(num) do
Enum.each(1..num, fn x->
 neigh1=if(rem(x,7)!=0 && x+1<=num) do x+1 end 
 neigh2=if(rem(x,7)!=1)do x-1 end
 neigh3=if(rem(x,2)!=0 && x+7<=num)do x+7 else if (rem(x,2)==0 && x-7>0) do x-7 end end
 list=[neigh1,neigh2,neigh3]
 |>Enum.reject(&is_nil/1)
 |>Enum.map(fn x->
  pname= "n_"<>Integer.to_string(x)
  pname
end)
 #IO.inspect list
    GPSERVER.updateNeighbours(String.to_atom("n_"<>Integer.to_string(x)), list)
end)
end

### honeycombR Topology ###

def honeyCombR(num) do
  Enum.each(1..num, fn x->
   neigh1=if(rem(x,7)!=0 && x+1<=num) do x+1 end 
   neigh2=if(rem(x,7)!=1)do x-1 end
   neigh3=if(rem(x,2)!=0 && x+7<=num)do x+7 else if (rem(x,2)==0 && x-7>0) do x-7 end end
   neigh4=Enum.random(1..num)
   list=[neigh1,neigh2,neigh3,neigh4]
   |>Enum.reject(&is_nil/1)
   |>Enum.map(fn x->
    pname= "n_"<>Integer.to_string(x)
    pname
  end)
    #IO.inspect list
      GPSERVER.updateNeighbours(String.to_atom("n_"<>Integer.to_string(x)), list)
  end)
end
end