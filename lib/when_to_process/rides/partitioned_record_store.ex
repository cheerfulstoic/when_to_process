defmodule WhenToProcess.Rides.PartitionedRecordStore do
  @moduledoc """
  For storing and retrieving single records.
  Uses PartitionSupervisor instead of having one process per record
  """

  alias WhenToProcess.Rides

  @behaviour Rides.State
  @behaviour Rides.GlobalState

  use GenServer

  def start_link(record_module) do
    # Taking just the uuid instead of the whole object because if the process restarts
    # we don't want to start off with old data.  We should re-fetch from the global state
    # each time the process gets started/restarted.
    GenServer.start_link(__MODULE__, record_module)
  end

  @impl Rides.State
  def state_child_spec(record_module) do
    {PartitionSupervisor,
     child_spec: child_spec(record_module), name: supervisor_name(record_module)}
  end

  def child_spec(record_module) do
    %{
      id: record_module,
      start: {__MODULE__, :start_link, [record_module]}
    }
  end

  @impl Rides.State
  def ready?(record_module), do: !!Process.whereis(supervisor_name(record_module))

  @impl Rides.State
  def reset(record_module) do
    child_pids(record_module)
    |> Enum.each(fn pid ->
      GenServer.call(pid, :reset)
    end)
  end

  @impl Rides.State
  def get(record_module, uuid), do: traced_call(record_module, uuid, {:get, uuid})

  @impl Rides.State
  def reload(%record_module{} = record) do
    get(record_module, record.uuid)
  end

  @impl Rides.State
  def insert_changeset(changeset) do
    %record_module{} = changeset.data

    record = Ecto.Changeset.apply_changes(changeset)

    # TODO: Check valid (?)
    traced_call(record_module, record.uuid, {:insert, record})
  end

  @impl Rides.State
  def update_changeset(changeset) do
    %record_module{} = changeset.data

    record = Ecto.Changeset.apply_changes(changeset)

    # TODO: Check valid (?)
    traced_call(record_module, record.uuid, {:update, record})
  end

  @impl Rides.GlobalState
  def list(record_module) do
    child_pids(record_module)
    |> Task.async_stream(fn pid ->
      traced_call(pid, :list)
    end)
    |> Enum.concat()
  end

  @impl Rides.GlobalState
  def count(record_module) do
    child_pids(record_module)
    |> Task.async_stream(fn pid ->
      traced_call(pid, :count)
    end)
    |> Enum.sum()
  end

  @impl Rides.GlobalState
  def list_nearby(record_module, position, distance, filter_fn, count) do
    child_pids(record_module)
    |> Task.async_stream(fn pid ->
      traced_call(pid, {:list_nearby, position, distance, filter_fn, count})
    end)
    |> Enum.concat()
    |> get_nearby(position, distance, filter_fn, count)
  end

  defp traced_call(record_module, uuid, message) do
    traced_call(
      via_name(record_module, uuid),
      message,
      %{
        record_module: WhenToProcessWeb.Telemetry.module_to_key(record_module),
      }
    )
  end

  defp traced_call(dest, message, metadata \\ %{}) do
    metadata = Map.merge(metadata, %{
      implementation_module: WhenToProcessWeb.Telemetry.module_to_key(__MODULE__),
      message_key: "#{message_key(message)}"
    })

    :telemetry.span(
      [:when_to_process, :rides, :genserver_call],
      metadata,
      fn ->
        result = GenServer.call(dest, message)
        {result, metadata}
      end
    )
  end

  defp child_pids(record_module) do
    PartitionSupervisor.which_children(supervisor_name(record_module))
    |> Enum.map(fn {_, pid, :worker, [__MODULE__]} ->
      pid
    end)
  end

  @impl true
  def init(_record_module) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:insert, record}, _from, records) do
    WhenToProcess.PubSub.broadcast_record_create(record)

    {:reply, {:ok, record}, Map.put(records, record.uuid, record)}
  end

  @impl true
  def handle_call({:update, record}, _from, records) do
    WhenToProcess.PubSub.broadcast_record_update(record)

    {:reply, {:ok, record}, Map.put(records, record.uuid, record)}
  end

  @impl true
  def handle_call({:get, uuid}, _from, records) do
    {:reply, Map.get(records, uuid), records}
  end

  @impl true
  def handle_call(:list, _from, records) do
    {:reply, Map.values(records), records}
  end

  @impl true
  def handle_call(:count, _from, records) do
    {:reply, map_size(records), records}
  end

  def handle_call({:list_nearby, position, distance, filter_fn, count}, _from, records) do
    result =
      records
      |> Enum.map(fn {_uuid, record} ->
        record
      end)
      |> get_nearby(position, distance, filter_fn, count)

    {:reply, result, records}
  end

  def get_nearby(records, position, distance, filter_fn, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    records
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
  end

  def handle_call(:reset, _from, _records) do
    {:reply, :ok, %{}}
  end

  # defp name(record_module) do
  #   :"partitioned_positioned_record_store_for_#{record_module}"
  # end

  def supervisor_name(record_module) do
    :"partitioned_record_store_for_#{record_module}"
  end

  defp via_name(record_module, uuid) do
    {:via, PartitionSupervisor, {supervisor_name(record_module), uuid}}
  end

  def message_key(message) when is_tuple(message), do: elem(message, 0)
  def message_key(message) when is_atom(message), do: message

  #   defp config do
  #     Application.get_env(:when_to_process, __MODULE__)
  #   end
end
