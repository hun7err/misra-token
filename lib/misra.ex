defmodule MisraToken do
  def propagate(rcpt, values) when values != [] do
    [h|t] = values
    send rcpt, h
    propagate rcpt, t
  end
  def propagate(_, values) when values == [], do: :ok

  defp regenerate(next, x), do: propagate next, [{:ping, abs(x)}, {:pong, -abs(x)}]
  defp incarnate(next, x), do: propagate next, [{:ping, abs(x)+1}, {:pong, -abs(x)-1}]
  
  def cs(i, coordinator) do
    send coordinator, {:cs_enter, i}
    IO.puts "entering CS on " <> to_string i
    :timer.sleep 1000
    send coordinator, {:cs_exit, i}
    IO.puts "leaving CS on " <> to_string i
  end

  def meeting(m, value), do: m*value < 0 and abs(value) == abs(m)

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

  def coordLoop(ids, ips, next, start \\ true) do
    if start do
      startNodes(ids, ips, next)
      IO.puts "nodes started, waiting for incoming messages..."
    end

    receive do
      {:start, id} ->
        IO.puts "node " <> to_string(id) <> " started"
      {:cs_enter, id} ->
        IO.puts "node " <> to_string(id) <> " entering cs"
      {:cs_exit, id} ->
        IO.puts "node " <> to_string(id) <> " leaving cs"
    end

    coordLoop(ips, ids, next, false)
  end

  def nodePid(ip_addr) do
    name = String.to_atom("misra@" <> ip_addr)
    Node.ping name
    Node.spawn_link name, fn -> :ok end
  end

  def start(i, next, coordinator) do
    IO.puts "node " <> to_string(i) <> " is getting PID for a neighbour at " <> next
    next = nodePid next
    IO.puts "neighbour pid for node " <> to_string(i) <> " is " <> to_string :erlang.pid_to_list(next)
    :timer.sleep 5000
    send coordinator, {:start, i}

    if i == 0, do: propagate self, [{:ping, 1}, {:pong, -1}]
    loop i, next, 0, coordinator
  end

  def loop(i, next, m, coordinator) do
    receive do
      {:ping, value} ->
        IO.puts "node " <> to_string(i) <> " received ping, value: " <> to_string(value)
        if m == value, do: regenerate next, value

        cs(i, coordinator)
        if meeting(m, value), do: incarnate next, value

        IO.puts "node " <> to_string(i) <> " sending :ping to " <> to_string(:erlang.pid_to_list(next))
        send next, {:ping, value+1}
        loop i, next, value, coordinator

      {:pong, value} ->
        IO.puts "node " <> to_string(i) <> " received pong, value: " <> to_string(value)
        if m == value, do: regenerate next, value

        :timer.sleep 500
        if meeting(m, value), do: incarnate next, value

        IO.puts "node " <> to_string(i) <> " sending :pong to " <> to_string(:erlang.pid_to_list(next))
        send next, {:pong, value-1}
        loop i, next, value, coordinator
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
