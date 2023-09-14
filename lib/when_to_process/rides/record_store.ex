defmodule WhenToProcess.Rides.RecordStore do
  @moduledoc """
  For storing and retrieving a single records of a particular type which has
  latitude and longitude properties
  """

  alias WhenToProcess.Rides

  @behaviour Rides.State

  use GenServer

  def start_link({record_module, uuid}) do
    # Taking just the uuid instead of the whole object because if the process restarts
    # we don't want to start off with old data.  We should re-fetch from the global state
    # each time the process gets started/restarted.
    GenServer.start_link(__MODULE__, {record_module, uuid}, name: name(record_module, uuid))
  end

  @impl Rides.State
  def state_child_spec(record_module) do
    {DynamicSupervisor, strategy: :one_for_one, name: supervisor_name(record_module)}
  end

  @impl Rides.State
  def ready?(record_module), do: !!Process.whereis(supervisor_name(record_module))

  @impl Rides.State
  def reset(record_module) do
    DynamicSupervisor.which_children(supervisor_name(record_module))
    |> Enum.each(fn {_, pid, :worker, [__MODULE__]} ->
      DynamicSupervisor.terminate_child(supervisor_name(record_module), pid)
    end)
  end

  @impl Rides.State
  def get(record_module, uuid), do: traced_call(record_module, uuid, :get)

  @impl Rides.State
  def reload(%record_module{} = record) do
    get(record_module, record.uuid)
  end

  @impl Rides.State
  def insert_changeset(changeset) do
    %record_module{} = changeset.data

    record = Ecto.Changeset.apply_changes(changeset)

    # TODO: Check valid (?)
    DynamicSupervisor.start_child(
      supervisor_name(record_module),
      {__MODULE__, {record_module, record.uuid}}
    )

    {:ok, record}
  end

  @impl Rides.State
  def update_changeset(changeset) do
    %record_module{} = changeset.data

    record = Ecto.Changeset.apply_changes(changeset)

    # TODO: Check valid (?)
    traced_call(record_module, record.uuid, {:update, record})
  end

  defp traced_call(record_module, uuid, message) do
    metadata = %{
      implementation_module: WhenToProcessWeb.Telemetry.module_to_key(__MODULE__),
      record_module: WhenToProcessWeb.Telemetry.module_to_key(record_module),
      message_key: "#{message_key(message)}"
    }

    :telemetry.span(
      [:when_to_process, :rides, :genserver_call],
      metadata,
      fn ->
        result = GenServer.call(name(record_module, uuid), message)
        {result, metadata}
      end
    )
  end

  @impl true
  def init({record_module, uuid}) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    record = Rides._global_state_implementation_module().get(record_module, uuid)

    WhenToProcess.PubSub.broadcast_record_create(record)

    {:ok, record}
  end

  @impl true
  def handle_call({:update, record}, _from, _) do
    WhenToProcess.PubSub.broadcast_record_update(record)

    {:reply, {:ok, record}, record}
  end

  @impl true
  def handle_call(:get, _from, record) do
    {:reply, record, record}
  end

  def supervisor_name(record_module) do
    :"positioned_record_store_dynamic_supervisor_for_#{record_module}"
  end

  defp name(record_module, uuid) do
    :"positioned_record_store_for_#{record_module}_#{uuid}"
  end

  def message_key(message) when is_tuple(message), do: elem(message, 0)
  def message_key(message) when is_atom(message), do: message
end
