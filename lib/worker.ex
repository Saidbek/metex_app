defmodule Metex.Worker do
  use GenServer # defines the callbacks reuired for GenServer

  # -------------------------------------------------------------------
  # | GenServer module calls...     | Callback module (Metex.Worker)  |
  # -------------------------------------------------------------------
  # | GenServer.start_link/3        | Metex.init/1                    |
  # | GenServer.call/3              | Metex.handle_call/3             |
  # | GenServer.cast/2              | Metex.handle_cast/2             |
  # -------------------------------------------------------------------

  ## Client API

  # store the name
  @name MW

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: MW]) # [name: MW] - initializes the server with a registered name
  end

  def get_temperature(location) do
    # call/3 makes a synchronous request to the server, this means a reply
    # from the server is expected. It expects handle_call/3 from callback module
    # cast/2 sibling, makes an asynchronous request to the server
    GenServer.call(@name, {:location, location})
  end

  def get_stats do
    GenServer.call(@name, :get_stats)
  end

  def reset_stats do
    GenServer.cast(@name, :reset_stats)
  end

  def stop do
    GenServer.cast(@name, :stop)
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_info(msg, stats) do
    IO.puts "received: #{inspect msg}"
    {:noreply, stats}
  end

  def terminate(reason, stats) do
    # we could write to a file, db etc.
    IO.puts "server terminated beause of #{inspect reason}"
    inspect stats
    :ok
  end

  def handle_cast(:stop, stats) do
    {:stop, :normal, stats}
  end

  def handle_cast(:reset_stats, _stats) do
    {:noreply, %{}}
  end

  def handle_call(:get_stats, _from, stats) do
    {:reply, stats, stats}
  end

  def handle_call({:location, location}, _from, stats) do
    # makes a request to the API for the location's temperature
    case temperature_of(location) do
      {:ok, temp} ->
        # updates the stats Map with the location frequency
        new_stats = update_stats(stats, location)
        # returns a three-element tuple as a response
        {:reply, "#{temp}C", new_stats}
      _ ->
        # returns a three-element tuple that has an :error tag
        {:reply, :error, stats}
    end
  end

  ## Helper Functions

  defp temperature_of(location) do
    url_for(location) |> HTTPoison.get |> parse_response
  end

  defp url_for(location) do
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{apikey()}"
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> JSON.decode! |> compute_temperature
  end

  defp parse_response(_) do
    :error
  end

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ -> :error
    end
  end

  # Simply check whether old_stats contains the location of the key.
  # If so fetch the value and increment the counter, otherwise put
  # a new key called location and set it to 1.
  defp update_stats(old_stats, location) do
    case Map.has_key?(old_stats, location) do
      true ->
        # &(&1 + 1) -> fn(val) -> val + 1 end
        Map.update!(old_stats, location, &(&1 + 1))
      false ->
        Map.put_new(old_stats, location, 1)
    end
  end

  defp apikey do
    "70e30eb0798fc68d046ed189e0f33f6c"
  end
end
