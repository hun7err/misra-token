defmodule MisraToken do
  def propagate(rcpt, values) when values != [] do
    [h|t] = values
    send rcpt, h
    propagate rcpt, t
  end
  def propagate(_, values) when values == [], do: :ok
  
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

    if i == 0, do:
      propagate self, [{:ping, 1}, {:pong, -1}]

    loop i, pid, 0, false
  end

  def coordLoop(ids, ips, next, nids, start \\ true) do
    if start do
      startNodes(ids, ips, next, nids)
      IO.puts "nodes started, waiting for incoming messages..."
    end
  end

  def loop(node_id, next_pid, m, in_cs) do
    :timer.sleep 1500
    #IO.puts "node " <> to_string(node_id) <> ": loop(m => " <> to_string(m) <> ", in_cs => " <> to_string(in_cs) <> ")"

    receive do
      {:csend, _} -> # CS end
        send next_pid, {:ping, abs(m)}

        loop node_id, next_pid, abs(m), false

      {:ping, value} ->
        IO.puts "node " <> to_string(node_id) <> ": PING with value " <> to_string(value)
        new_m = m

        if m == value do
          IO.puts "node " <> to_string(node_id) <> ": PONG lost, regenerating with value=" <> to_string(-value)
          send next_pid, {:pong, -value}
          new_m = -value
        end

        if not in_cs do
          spawn(MisraToken, :cs, [node_id, self, value])
          loop node_id, next_pid, new_m, true
        else
          loop node_id, next_pid, new_m, in_cs
        end

      {:pong, value} ->
        if node_id != 2 or value > -3 do
          new_m = m

          if m == value and not in_cs do
            IO.puts "node " <> to_string(node_id) <> ": PING lost, regenerating with value=" <> to_string(abs(value))
            send next_pid, {:ping, abs(value)}
          end

          IO.puts "node " <> to_string(node_id) <> ": PONG with value " <> to_string(value)

          if not in_cs do
            send next_pid, {:pong, value}
            loop node_id, next_pid, value, in_cs
          else
            send next_pid, {:pong, value-1}
            loop node_id, next_pid, value-1, in_cs
          end
        else
          loop node_id, next_pid, m, in_cs
        end
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
