defmodule MisraToken do
  def propagate(rcpt, values) when values != [] do
    [h|t] = values
    send rcpt, h
    propagate rcpt, t
  end
  def propagate(_, values) when values == [], do: :ok

  defp regenerate(next, x), do: propagate next, [{:ping, abs(x)}, {:pong, -abs(x)}]
  defp incarnate(next, x), do: propagate next, [{:ping, abs(x)+1}, {:pong, -abs(x)-1}]
  
  def cs(i) do
    IO.puts "entering CS on " <> to_string i
    :timer.sleep 1000
    IO.puts "leaving CS on " <> to_string i
  end

  def meeting(m, value), do: m*value < 0

  def start(i, next) do
    if i == 0, do: propagate self, [{:ping, 1}, {:pong, -1}]
    loop i, next, 0
  end

  def loop(i, next, m) do
    receive do
      {:ping, value} ->
        if m == value, do: regenerate next, value

        cs(i)
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
      next = String.atom("misra@" <> next_ip)
      Node.ping node

      pid = Node.spawn_link next, fn -> :ok end
      
      MisraToken.start id, pid
    end
  end
end
