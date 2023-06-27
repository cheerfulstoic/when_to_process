defmodule WhenToProcess.Rides.ProcessesWithETS do
  @behaviour WhenToProcess.Rides

  alias WhenToProcess.Rides
  alias WhenToProcess.Rides.DriverServer

  alias WhenToProcess.Rides.Passenger

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
  def list(Rides.Driver), do: __MODULE__.DriverInformation.query_all()
  @impl Rides
  def count(Rides.Driver), do: __MODULE__.DriverInformation.count()
  @impl Rides
  def get(Rides.Driver, uuid), do: DriverServer.get_driver(uuid)
  @impl Rides
  def reload(record), do: DriverServer.get_driver(record.uuid)
  @impl Rides
  def available_drivers(position, count), do: __MODULE__.DriverInformation.list_nearby(position, 2_000, count)

  # TODO
  @impl Rides
  def cancel_request(%Passenger{} = _passenger) do
    nil
  end

  # TODO
  @impl Rides
  def reject_ride_request(_ride_request, _driver) do
  end

  @impl Rides
  def reset(Rides.Driver) do
    __MODULE__.DriverInformation.reset()
    DriverServer.reset()

    :ok
  end
  def reset(_) do
    :ok
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
