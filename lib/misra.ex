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

  def meeting(m, value), do: m*value < 0

  def startNodes(ips, ids, next) when ips != [] do
    [ip_head|ip_tail] = ips
    [id_head|id_tail] = ids
    [nx_head|nx_tail] = next

    name = String.to_atom("misra@" <> ip_head)
    Node.ping name
    Node.spawn_link name, MisraToken, :start, id_head, nx_head, self

    startNodes ip_tail, id_tail, nx_tail
  end
  def startNodes(ips, ids, next) when ips == [], do: :ok

  def coordStart(ips, ids, next) do
    # ...
    startNodes ips, ids, next

    receive do
      {:cs_enter, id} ->
        IO.puts to_string(id) <> " entering cs"
      {:cs_exit, id} ->
        IO.puts to_string(id) <> " leaving cs"
    end
  end

  def start(i, next, coordinator) do
    if i == 0, do: propagate self, [{:ping, 1}, {:pong, -1}]
    loop i, next, 0, coordinator
  end

  def loop(i, next, m, coordinator) do
    receive do
      {:ping, value} ->
        if m == value, do: regenerate next, value

        cs(i, coordinator)
        if meeting(m, value), do: incarnate next, value

        send next, {:ping, value+1}
        loop i, next, value

      {:pong, value} ->
        if m == value, do: regenerate next, value

        :timer.sleep 500
        if meeting(m, value), do: incarnate next, value

        send next, {:pong, value-1}
        loop i, next, value
    end
  end

  def nodePid(ip_addr) do
    name = String.atom("misra@" <> ip_addr)
    Node.spawn_link name, fn -> :ok end
  end

  def init(next_ip, id) do
    pid = nodePid next_ip

    :timer.sleep 5000
    start id, pid
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
