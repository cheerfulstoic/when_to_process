defmodule WhenToProcess.Rides.ProcessesOnly do
  @behaviour WhenToProcess.Rides

  alias WhenToProcess.Rides
  alias WhenToProcess.Rides.DriverServer

  @impl Rides
  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__.Supervisor, :start_link, [[nil]]}
    }
  end


  @impl Rides
  def ready?, do: WhenToProcess.Supervisor.ready?(__MODULE__.Supervisor)
  @impl Rides
  def list_drivers, do: __MODULE__.DriverInformation.query_all()
  @impl Rides
  def count_drivers, do: __MODULE__.DriverInformation.count()
  @impl Rides
  def get_driver!(uuid), do: DriverServer.get_driver(uuid)
  @impl Rides
  def available_drivers(position, count), do: __MODULE__.DriverInformation.top_ready_near(position, 2_000, count)

  @impl Rides
  def reset do
    # TODO: Need to remove the DriverServer processes
    __MODULE__.DriverInformation.reset()
  end

  @impl Rides
  def insert_changeset(%Ecto.Changeset{} = changeset) do
    # TODO: Be able to deal with more than just drivers
    record = Ecto.Changeset.apply_changes(changeset)

    case DriverServer.create(record) do
      {:ok, _pid} ->
        WhenToProcess.PubSub.broadcast_record_create(record)

        __MODULE__.DriverInformation.insert_new(record)

        {:ok, record}
      {:error, _} = error -> error
    end
  end

  @impl Rides
  def update_changeset(%Ecto.Changeset{} = changeset) do
    # TODO: Be able to deal with more than just drivers
    record = Ecto.Changeset.apply_changes(changeset)

    with {:ok, record} <- DriverServer.update_driver(record) do
      WhenToProcess.PubSub.broadcast_record_update(record)

      __MODULE__.DriverInformation.update(record)

      {:ok, record}
    end
  end
end

