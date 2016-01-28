defmodule MisraToken do
  def propagate(rcpt, values) when values != [] do
    [h|t] = values
    send rcpt, h
    propagate rcpt, t
  end
  def propagate(_, values) when values == [], do: :ok

  defp regenerate(x), do: {abs(x), -abs(x)}
  defp incarnate(next, x), do: propagate next, [{:ping, abs(x)+1}, {:pong, -abs(x)-1}]
  
  def cs(i, parent, value) do
    IO.puts "node " <> to_string(i) <> ": entering CS"
    :timer.sleep 2000
    IO.puts "node " <> to_string(i) <> ": leaving CS"
    
    send parent, {:csend, value}
  end

  def startNodes(ids, ips, next, nid) when ips != [] do
    [ip_head|ip_tail] = ips
    [id_head|id_tail] = ids
    [nx_head|nx_tail] = next
    [ni_head|ni_tail] = nid

    name = String.to_atom("misra@" <> ip_head)
    Node.ping name
    Node.spawn_link name, MisraToken, :start, [id_head, nx_head, ni_head, self]

    startNodes id_tail, ip_tail, nx_tail, ni_tail
  end
  def startNodes(ids, _, _, _) when ids == [], do: :ok

  def nodePid(i, id) do
    IO.puts "node " <> to_string(i) <> ": trying 'misra" <> to_string(id) <> "'..."
    :global.whereis_name String.to_atom("misra" <> to_string(id))
  end

  def start(i, next_ip, next_id, coordinator) do
    :global.register_name String.to_atom("misra" <> to_string(i)), self
    :timer.sleep 1500
    name = String.to_atom("misra@" <> next_ip)
    ret = Node.ping name
    IO.puts "node " <> to_string(i) <> ": ping :\"misra@" <> next_ip <> "\" returned :" <> to_string(ret)
    :timer.sleep 1500

    IO.puts "node " <> to_string(i) <> ": getting PID for a neighbour at " <> next_ip
    pid = nodePid i, next_id
    IO.puts "node " <> to_string(i) <> ": neighbour pid for node " <> to_string(i) <> " is " <> to_string :erlang.pid_to_list(pid)

    :timer.sleep 1000

    send coordinator, {:start, i}

    pingPid = spawn MisraToken, :loop, [:ping, i, pid, 0, false, false]
    pongPid = spawn MisraToken, :loop, [:pong, i, pid, 0, false, false]

    if i == 0, do:
      propagate self, [{:ping, 1}, {:pong, -1}]

    supervisor i, pingPid, pongPid
  end

  def supervisor(id, pingPid, pongPid) do
    :timer.sleep 1500

    receive do
      {what, value} ->
        IO.puts "node " <> to_string(id) <> ": supervisor received '" <> to_string(what) <> "' with value " <> to_string(value)

        if what == :ping do
          send pingPid, {what, value}
        else
          send pongPid, {what, value}
        end
    end

    supervisor id, pingPid, pongPid
  end

  def coordLoop(ids, ips, next, nids, start \\ true) do
    if start do
      startNodes(ids, ips, next, nids)
      IO.puts "nodes started, waiting for incoming messages..."
    end
  end

  def other(what, values) do
    {ping, pong} = values
    case what do
      :ping -> {:pong, pong}
      :pong -> {:ping, ping}
    end
  end

  def loop(what, node_id, next_pid, m, has_ping, has_pong) do
    receive do
      {:csend, value} -> # CS end
        if has_pong and abs(m) == abs(value) do
          IO.puts "node " <> to_string(node_id) <>": INCarnating tokens"
          incarnate next_pid, value
        else
          IO.puts "node " <> to_string(node_id) <> ": PASSing PING to the next node"
          send next_pid, {:ping, value}
        end

        loop(what, node_id, next_pid, value, false, has_pong)

      {what, value} ->
        if m == value do
          IO.puts "node " <> to_string(node_id) <> ": REGENerating tokens"

          msg = other what, regenerate(value)
          {_, value} = msg
          send next_pid, msg
        end
           
        if what == :ping do
          if not has_ping do
            spawn MisraToken, :cs, [node_id, self, value]
            loop what, node_id, next_pid, m, true, has_pong
          else
            send self, {:ping, value}
            loop what, node_id, next_pid, m, true, has_pong
          end
        else
          if not has_ping, do:
            send(next_pid, {:pong, value}),
          else:
            send(self, {:pong, value})
          loop what, node_id, next_pid, value, has_ping, true
        end
      #{:chm, next_m} -> # change of "m"
        #loop what, node_id, next_pid, next_m, other_pid, has_ping, has_pong
      #{:chstate, state} ->  # what did I do this for, exactly?
      #  loop what, node_id, next_pid, m, other_pid, has_ping, has_pong
    end
  end

  def main(args) do
    switches = [id: :integer, count: :integer, ip: :string, next: :string]
    {options, _, _} = OptionParser.parse args, switches: switches

    if MapSet.new(options) != MapSet.new(Dict.keys(switches)) do
      IO.puts "Usage:\n./misra --id [nodeId] --count [nodeCount] --ip [nodeIp] --next [nextNodeIp]"
      1
    else
      id = Dict.fetch! options, :id
      node_count = Dict.fetch! options, :count
      my_ip = Dict.fetch! options, :ip
      next_ip = Dict.fetch! options, :next

      Node.start String.to_atom("misra@" <> my_ip)
      
      pid = nodePid id, 0  # TODO: fix
      
      :timer.sleep 5000
      MisraToken.start id, pid
    end
  end
end
