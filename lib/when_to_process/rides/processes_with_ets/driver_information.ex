defmodule WhenToProcess.Rides.ProcessesWithETS.DriverInformation do
  use GenServer

  require Ex2ms

  alias WhenToProcess.Rides

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def insert_new(driver) do
    traced_call({:insert_new, driver})
  end

  def query_all do
    ms = Ex2ms.fun do
      {_uuid, _driver_latitude, _driver_longitude, driver} -> driver
    end

    :ets.select(__MODULE__, ms)
  end

  def count do
    ms = Ex2ms.fun do
      {_uuid, _driver_latitude, _driver_longitude, _driver} -> true
    end

    :ets.select_count(__MODULE__, ms)
  end

  def list_nearby(position, distance, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    ms = Ex2ms.fun do
      {uuid, driver_latitude, driver_longitude, driver} when driver_latitude >= ^latitude_west and driver_latitude <= ^latitude_east and driver_longitude >= ^longitude_south and driver_longitude <= ^longitude_north -> driver
    end

    :ets.select(__MODULE__, ms)
    |> Enum.filter(& &1.ready_for_passengers)
    |> Enum.sort_by(fn driver ->
      Rides.sort_distance(position, Rides.position(driver))
    end)
    |> Enum.take(count)
  end

  def update(driver) do
    traced_call({:update, driver})
  end

  def reset do
    traced_call(:reset)
  end

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

    :ets.new(__MODULE__, [:set, :protected, :named_table])

    {:ok, nil}
  end

  @impl true
  def handle_call({:insert_new, driver}, _from, nil) do
    result = :ets.insert_new(__MODULE__, ets_tuple(driver))

    {:reply, result, nil}
  end

  @impl true
  def handle_call({:update, driver}, _from, nil) do
    result = :ets.update_element(__MODULE__, driver.uuid, [
      {2, driver.latitude},
      {3, driver.longitude},
      {4, driver}
    ])

    {:reply, result, nil}
  end

  @impl true
  def handle_call(:reset, _from, nil) do
    result = :ets.delete_all_objects(__MODULE__)

    {:reply, result, nil}
  end

  defp ets_tuple(driver) do
    {driver.uuid, driver.latitude, driver.longitude, driver}
  end
end

