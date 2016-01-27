defmodule MisraToken do
  def propagate(rcpt, values) when values != [] do
    [h|t] = values
    send rcpt, h
    propagate rcpt, t
  end
  def propagate(_, values) when values == [], do: :ok

  defp regenerate(x), do: {abs(x), -abs(x)}
  defp incarnate(next, x), do: propagate next, [{:ping, abs(x)+1}, {:pong, -abs(x)-1}]
  
  def cs(i, parent) do
    IO.puts "node " <> to_string(i) <> ": entering CS"
    :timer.sleep 1000
    IO.puts "node " <> to_string(i) <> ": leaving CS"
    
    send parent, :csend
  end

  # def meeting(m, value), do: m*value < 0 and abs(value) == abs(m)

  def startNodes(ids, ips, next) when ips != [] do
    [ip_head|ip_tail] = ips
    [id_head|id_tail] = ids
    [nx_head|nx_tail] = next

    name = String.to_atom("misra@" <> ip_head)
    Node.ping name
    Node.spawn_link name, MisraToken, :start, [id_head, nx_head, self]

    startNodes id_tail, ip_tail, nx_tail
  end
  def startNodes(ids, _, _) when ids == [], do: :ok

  def nodePid(ip_addr) do
    name = String.to_atom("misra@" <> ip_addr)
    Node.ping name
    Node.spawn_link name, fn -> :ok end
  end

  def start(i, next, coordinator) do
    IO.puts "node " <> to_string(i) <> " is getting PID for a neighbour at " <> next
    pid = nodePid next
    IO.puts "neighbour pid for node " <> to_string(i) <> " is " <> to_string :erlang.pid_to_list(pid)
    :timer.sleep 5000
    send coordinator, {:start, i}

    if i == 0, do:
      propagate self, [{:ping, 1}, {:pong, -1}]

    pingPid = spawn MisraToken, :loop, [:ping, i, pid, 0, false, false]
    pongPid = spawn MisraToken, :loop, [:pong, i, pid, 0, false, false]

    send pingPid, {:ping, 1}
    send pongPid, {:pong, -1}

    supervisor pingPid, pongPid
  end

  def supervisor(pingPid, pongPid) do
    receive do
      {what, value} ->
        if what in [:ping, :csend] do
          send pingPid, {what, value}
        else
          send pongPid, {what, value}
        end
    end
  end

  def coordLoop(ids, ips, next, start \\ true) do
    if start do
      startNodes(ids, ips, next)
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
    :timer.sleep 300

    receive do
      {:csend, value} -> # CS end
        send next_pid, {:ping, value}
        
        loop(what, node_id, next_pid, value, false, has_pong)

      {what, value} ->
        if m == value do
          IO.puts "node " <> to_string(node_id) <> ": regenerating tokens"
          msg = other what, regenerate(value)
          {_, value} = msg
          send next_pid, msg
        end
          
        if has_ping and has_pong and abs(m) == abs(value) do
          incarnate next_pid, value
        end

        if what == :ping do
          if not has_ping do
            spawn MisraToken, :cs, [node_id, self]
            loop what, node_id, next_pid, m, true, has_pong
          else
            send self, {:ping, value}
            loop what, node_id, next_pid, m, true, has_pong
          end
        else
          send next_pid, {:pong, value}
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
      
      pid = nodePid next_ip
      
      :timer.sleep 5000
      MisraToken.start id, pid
    end
  end
end
