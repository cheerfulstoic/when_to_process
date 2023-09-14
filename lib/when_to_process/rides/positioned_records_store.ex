defmodule WhenToProcess.Rides.PositionedRecordsStore do
  @moduledoc """
  For storing and searching a list of records of a particular type which have
  latitude and longitude properties
  """

  alias WhenToProcess.Rides

  @behaviour Rides.State
  @behaviour Rides.GlobalState

  use GenServer

  def start_link(record_module) do
    GenServer.start_link(__MODULE__, nil, name: name(record_module))
  end

  @impl Rides.State
  def state_child_spec(record_module) do
    %{
      id: name(record_module),
      start: {__MODULE__, :start_link, [record_module]}
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
  def list(record_module), do: traced_call(record_module, :list)

  @impl Rides.GlobalState
  def count(record_module), do: traced_call(record_module, :count)

  @impl Rides.GlobalState
  def list_nearby(record_module, position, distance, filter_fn, count),
    do: traced_call(record_module, {:list_nearby, position, distance, filter_fn, count})

  @impl Rides.State
  def get(record_module, uuid), do: traced_call(record_module, {:get, uuid})

  @impl Rides.State
  def reload(%record_module{} = record) do
    get(record_module, record.uuid)
  end

  defp traced_call(record_module, message) do
    metadata = %{
      implementation_module: WhenToProcessWeb.Telemetry.module_to_key(__MODULE__),
      record_module: WhenToProcessWeb.Telemetry.module_to_key(record_module),
      message_key: "#{message_key(message)}"
    }

    :telemetry.span(
      [:when_to_process, :rides, :genserver_call],
      metadata,
      fn ->
        result = GenServer.call(name(record_module), message)
        {result, metadata}
      end
    )
  end


  defp name(record_module) do
    :"positioned_records_store_for_#{record_module}"
  end

  def message_key(message) when is_tuple(message), do: elem(message, 0)
  def message_key(message) when is_atom(message), do: message

  # Server-side

  @impl true
  def init(_) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:insert_new, record}, _from, record_map) do
    record_map = Map.put(record_map, record.uuid, record)

    WhenToProcess.PubSub.broadcast_record_create(record)

    {:reply, {:ok, record}, record_map}
  end

  @impl true
  def handle_call(:list, _from, record_map) do
    {:reply, Map.values(record_map), record_map}
  end

  @impl true
  def handle_call(:count, _from, record_map) do
    {:reply, map_size(record_map), record_map}
  end

  @impl true
  def handle_call({:get, uuid}, _from, record_map) do
    {:reply, Map.get(record_map, uuid), record_map}
  end

  def handle_call({:list_nearby, position, distance, filter_fn, count}, _from, record_map) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    result =
      record_map
      |> Enum.filter(fn {_uuid, record} ->
        record.latitude >= latitude_west &&
          record.latitude <= latitude_east &&
          record.longitude >= longitude_south &&
          record.longitude <= longitude_north
      end)
      |> Enum.map(fn {_uuid, record} -> record end)
      # |> Enum.filter(& &1.ready_for_passengers)
      |> Enum.filter(filter_fn)
      |> Enum.sort_by(fn record ->
        Rides.sort_distance(position, Rides.position(record))
      end)
      |> Enum.take(count)

    {:reply, result, record_map}
  end

  @impl true
  def handle_call({:update, record}, _from, record_map) do
    record_map = Map.put(record_map, record.uuid, record)

    WhenToProcess.PubSub.broadcast_record_update(record)

    {:reply, {:ok, record}, record_map}
  end

  @impl true
  def handle_call(:ready?, _from, record_map) do
    {:reply, true, record_map}
  end

  @impl true
  def handle_call(:reset, _from, _record_map) do
    {:reply, true, %{}}
  end
end
