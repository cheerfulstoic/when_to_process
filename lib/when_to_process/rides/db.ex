defmodule WhenToProcess.Rides.DB do
  import Ecto.Query

  alias WhenToProcess.Repo
  alias WhenToProcess.Rides
  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.RideRequest

  @behaviour Rides.State
  @behaviour Rides.GlobalState
  @behaviour Rides.IndividualState

  @impl Rides.State
  def child_spec(_record_module), do: nil

  @impl Rides.State
  def ready?(_record_module) do
    WhenToProcess.Repo in Ecto.Repo.all_running()
  end

  @impl Rides.GlobalState
  def list(record_module), do: Repo.all(record_module)

  @impl Rides.GlobalState
  def count(record_module) do
    Repo.aggregate(record_module, :count)
  end

  @impl Rides.IndividualState
  def get(record_module, uuid), do: Repo.get_by(record_module, uuid: uuid)

  @impl Rides.IndividualState
  def reload(record), do: Repo.reload(record)

  @impl Rides.State
  def reset(_record_module) do
    :ok
  end

  @impl Rides.GlobalState
  def list_nearby(record_module, position, distance, filter_fn, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    {latitude, longitude} = position

    from(
      driver in record_module,
      where: fragment("? BETWEEN ? AND ?", driver.latitude, ^latitude_west, ^latitude_east),
      where: fragment("? BETWEEN ? AND ?", driver.longitude, ^longitude_south, ^longitude_north),
      order_by: fragment("pow(? - ?, 2) + pow(? - ?, 2)", ^latitude, driver.latitude, ^longitude, driver.longitude),
      limit: ^count
    )
    |> Repo.all()
    |> Enum.filter(filter_fn)
  end

  @impl Rides
  def cancel_request(%Passenger{} = passenger) do
    result =
      passenger.ride_request
      |> RideRequest.changeset(%{cancelled_at: DateTime.utc_now()})
      |> update_changeset()

    with {:ok, _ride_request} <- result do
      {:ok,
        passenger
        |> Repo.preload(:ride_request, force: true)
        |> WhenToProcess.PubSub.broadcast_record_update()
      }
    end
  end

  @impl Rides.State
  def insert_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.insert(changeset) do
      WhenToProcess.PubSub.broadcast_record_create(record)

      {:ok, record}
    end
  end

  @impl Rides.State
  def update_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.update(changeset) do
      WhenToProcess.PubSub.broadcast_record_update(record)

      {:ok, record}
    end
  end
end
