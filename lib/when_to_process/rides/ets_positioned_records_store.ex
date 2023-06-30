defmodule WhenToProcess.Rides.ETSPositionedRecordsStore do
  alias WhenToProcess.Rides

  @behaviour Rides.State
  @behaviour Rides.GlobalState
  @behaviour Rides.IndividualState

  use GenServer

  require Ex2ms

  def start_link(record_module) do
    GenServer.start_link(__MODULE__, record_module, name: name(record_module))
  end

  @impl Rides.State
  def state_child_spec(record_module) do
    %{
      id: name(record_module),
      start: {__MODULE__, :start_link, [record_module]},
    }
  end

  @impl Rides.State
  def ready?(record_module), do: !!Process.whereis(name(record_module))

  @impl Rides.State
  def reset(record_module), do: traced_call(record_module, :reset)

  @impl Rides.State
  def insert_changeset(changeset) do
    %record_module{} = changeset.data

    record = Ecto.Changeset.apply_changes(changeset)

    # TODO: Check valid (?)
    traced_call(record_module, {:insert_new, record})
  end

  @impl Rides.State
  def update_changeset(changeset) do
    %record_module{} = changeset.data

    record = Ecto.Changeset.apply_changes(changeset)

    # TODO: Check valid (?)
    traced_call(record_module, {:update, record})
  end

  @impl Rides.GlobalState
  def list(record_module) do
    ms = Ex2ms.fun do
      {_uuid, _driver_latitude, _driver_longitude, driver} -> driver
    end

    :ets.select(table_name(record_module), ms)
  end

  @impl Rides.GlobalState
  def count(record_module) do
    ms = Ex2ms.fun do
      {_uuid, _driver_latitude, _driver_longitude, _driver} -> true
    end

    :ets.select_count(table_name(record_module), ms)
  end

  @impl Rides.GlobalState
  def list_nearby(record_module, position, distance, filter_fn, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    ms = Ex2ms.fun do
      {uuid, driver_latitude, driver_longitude, driver} when driver_latitude >= ^latitude_west and driver_latitude <= ^latitude_east and driver_longitude >= ^longitude_south and driver_longitude <= ^longitude_north -> driver
    end

    :ets.select(table_name(record_module), ms)
    |> Enum.filter(filter_fn)
    |> Enum.sort_by(fn driver ->
      Rides.sort_distance(position, Rides.position(driver))
    end)
    |> Enum.take(count)
  end

  @impl Rides
  def cancel_request(%Passenger{} = passenger) do
    raise "TODO!"
  end

  @impl Rides.IndividualState
  def get(record_module, uuid) do
    case :ets.lookup(table_name(record_module), uuid) do
      [{_, _, _, record}] ->
        record

      _ -> nil
    end
  end

  @impl Rides.IndividualState
  def reload(%record_module{} = record) do
    get(record_module, record.uuid)
  end

  defp traced_call(record_module, message) do
    message_key = "#{message_key(message)}"
    :telemetry.span(
      [:when_to_process, :rides, :ets_positioned_records_store, record_module],
      %{message_key: message_key},
      fn ->
        result = GenServer.call(name(record_module), message)
        {result, %{message_key: message_key}}
      end
    )
  end

  defp name(record_module) do
    :"ets_positioned_records_store_for_#{record_module}"
  end

  def message_key({key, _}), do: key
  def message_key(message) when is_atom(message), do: message

  # Server-side

  @impl true
  def init(record_module) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    :ets.new(table_name(record_module), [:set, :protected, :named_table])

    {:ok, record_module}
  end

  @impl true
  def handle_call(:reset, _from, record_module) do
    result = :ets.delete_all_objects(table_name(record_module))

    {:reply, result, record_module}
  end

  @impl true
  def handle_call({:insert_new, record}, _from, record_module) do
    :ets.insert_new(table_name(record_module), ets_tuple(record))

    {:reply, {:ok, record}, record_module}
  end

  @impl true
  def handle_call({:update, record}, _from, record_module) do
    :ets.update_element(table_name(record_module), record.uuid, [
      {2, record.latitude},
      {3, record.longitude},
      {4, record}
    ])

    {:reply, {:ok, record}, record_module}
  end

  defp ets_tuple(record) do
    {record.uuid, record.latitude, record.longitude, record}
  end

  def table_name(record_module) do
    :"#{__MODULE__}_#{record_module}"
  end
end

