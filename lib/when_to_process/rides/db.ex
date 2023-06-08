defmodule WhenToProcess.Rides.DB do
  @behaviour WhenToProcess.Rides

  import Ecto.Query

  alias WhenToProcess.Repo
  alias WhenToProcess.Rides
  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.RideRequest

  @impl Rides
  def child_spec, do: nil

  @impl Rides
  def ready? do
    WhenToProcess.Repo in Ecto.Repo.all_running()
  end

  @impl Rides
  def list_drivers do
    Repo.all(Driver)
  end

  @impl Rides
  def count_drivers do
    Repo.aggregate(Driver, :count)
  end

  @impl Rides
  def get_driver!(uuid), do: Repo.get_by!(Driver, uuid: uuid)

  @impl Rides
  def reload(record), do: Repo.reload(record)

  @impl Rides
  def available_drivers(position, count) do
    position
    |> nearby_drivers_q(2_000, count)
    |> where([driver], driver.ready_for_passengers == true)
    |> Repo.all()
  end

  @impl Rides
  def reject_ride_request(_ride_request, _driver) do
    # TODO

    nil
  end

  @impl Rides
  def reset do
    true
  end

  defp nearby_drivers_q(position, radius, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, radius)

    {latitude, longitude} = position
    from(
      driver in Driver,
      where: fragment("? BETWEEN ? AND ?", driver.latitude, ^latitude_west, ^latitude_east),
      where: fragment("? BETWEEN ? AND ?", driver.longitude, ^longitude_south, ^longitude_north),
      order_by: fragment("pow(? - ?, 2) + pow(? - ?, 2)", ^latitude, driver.latitude, ^longitude, driver.longitude),
      limit: ^count
    )
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

  @impl Rides
  def insert_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.insert(changeset) do
      WhenToProcess.PubSub.broadcast_record_create(record)

      {:ok, record}
    end
  end

  @impl Rides
  def update_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.update(changeset) do
      WhenToProcess.PubSub.broadcast_record_update(record)

      {:ok, record}
    end
  end
end
