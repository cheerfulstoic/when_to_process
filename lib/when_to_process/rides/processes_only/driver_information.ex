defmodule WhenToProcess.Rides.ProcessesOnly.DriverInformation do
  use GenServer

  alias WhenToProcess.Rides

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def insert_new(driver), do: traced_call({:insert_new, driver})
  def query_all, do: traced_call(:query_all)
  def count, do: traced_call(:count)
  def top_ready_near(position, distance, count), do: traced_call({:top_ready_near, position, distance, count})
  def update(driver), do: traced_call({:update, driver})
  def reset, do: traced_call(:reset)

  defp traced_call(message) do
    message_key = "#{message_key(message)}"
    :telemetry.span(
      [:when_to_process, :rides, :processes_only, :driver_information],
      %{message_key: message_key},
      fn ->
        result = GenServer.call(__MODULE__, message)
        {result, %{message_key: message_key}}
      end
    )
  end

  def message_key({key, _}), do: key
  def message_key(message) when is_atom(message), do: message

  # Server-side

  @impl true
  def init(_) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:insert_new, driver}, _from, driver_map) do
    driver_map = Map.put(driver_map, driver.uuid, driver)

    {:reply, true, driver_map}
  end

  @impl true
  def handle_call(:query_all, _from, driver_map) do
    {:reply, Map.values(driver_map), driver_map}
  end

  @impl true
  def handle_call(:count, _from, driver_map) do
    {:reply, map_size(driver_map), driver_map}
  end

  def handle_call({:top_ready_near, position, distance, count}, _from, driver_map) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    result =
      driver_map
      |> Enum.filter(fn {_uuid, driver} ->
        driver.latitude >= latitude_west &&
        driver.latitude <= latitude_east &&
        driver.longitude >= longitude_south &&
        driver.longitude <= longitude_north
      end)
      |> Enum.filter(& &1.ready_for_passengers)
      |> Enum.sort_by(fn driver ->
        Rides.sort_distance(position, Rides.position(driver))
      end)
      |> Enum.take(count)

    {:reply, result, driver_map}
  end

  @impl true
  def handle_call({:update, driver}, _from, driver_map) do
    driver_map = Map.put(driver_map, driver.uuid, driver)

    {:reply, true, driver_map}
  end

  @impl true
  def handle_call(:reset, _from, _driver_map) do
    {:reply, true, %{}}
  end

end

