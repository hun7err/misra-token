defmodule MisraToken do
  def next(i) do
  end

  def propagate(rcpt, values) when values != [], do: [h|t] = values; send rcpt, h; propagate t
  def propagate(rcpt, values) when values == [], do: :ok

  defp regenerate(x), do: propagate next, [{:ping, abs(x)}, {:pong, -abs(x)}]
  defp incarnate(x), do: propagate next, [{:ping, abs(x)+1}, {:pong, -abs(x)-1}]
  
  def cs(i) do
    IO.puts "entering CS on " <> to_string i
    :timer.sleep 1000
    IO.puts "leaving CS on " <> to_string i
  end

  def meeting(m, value), do: m*value < 0

  def start(i) do
    if i == 0, do: propagate self, [{:ping, 1}, {:pong, -1}]
    loop i, 0
  end

  def loop(i, m) do
    receive do
      {:ping, value} ->
        if m == value, do: regenerate value

        cs(i)
        if meeting, do: incarnate value

        send next, {:ping, value+1}
        loop i, value

      {:pong, value} ->
        if m == value, do: regenerate value

        :timer.sleep 500
        if meeting, do: incarnate value

        send next, {:pong, value-1}
        loop i, value
    end
  end
end
