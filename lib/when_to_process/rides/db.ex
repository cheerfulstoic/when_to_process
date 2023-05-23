defmodule WhenToProcess.Rides.DB do
  @behaviour WhenToProcess.Rides

  import Ecto.Query

  alias WhenToProcess.Repo
  alias WhenToProcess.Rides
  alias WhenToProcess.Rides.Ride
  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.RideRequest

  def create_driver(attrs \\ %{}) do
    %Driver{}
    |> Driver.changeset(attrs)
    |> insert_changeset()
  end

  def create_passenger(attrs \\ %{}) do
    %Passenger{}
    |> Passenger.changeset(attrs)
    |> insert_changeset()
  end

  def set_position(driver, new_position) do
    driver
    |> Driver.changeset(%{position: new_position})
    |> update_changeset()
  end

  def go_online(driver) do
    driver
    |> Driver.changeset(%{ready_for_passengers: true})
    |> update_changeset()
  end

  def no_more_passengers(driver) do
    driver
    |> Driver.changeset(%{ready_for_passengers: false})
    |> update_changeset()
  end

  def request_ride(%Passenger{} = passenger) do
    result =
      passenger
      |> Passenger.changeset(%{ride_request: %{}})
      |> update_changeset()

    with {:ok, passenger} <- result do
      passenger
      |> Rides.position()
      # TODO: Only query for drivers which are ready_for_passengers = true
      |> nearby_drivers(2_000, 3)
      |> Enum.each(fn driver ->
        IO.puts("broadcasting to driver #{driver.id}")
        Phoenix.PubSub.broadcast(WhenToProcess.PubSub, "driver:#{driver.id}", {:new_ride_request, passenger.ride_request})
      end)

      {:ok, passenger}
    end
  end

  def accept_ride_request(ride_request, driver) do
    ride_request = Repo.reload(ride_request)

    with :ok <- RideRequest.check_can_be_accepted(ride_request) do
      %Ride{}
      |> Ride.changeset(%{driver_id: driver.id, ride_request_id: ride_request.id})
      |> Repo.insert()
      |> case do
        {:ok, ride} ->
          Phoenix.PubSub.broadcast(WhenToProcess.PubSub, "passenger:#{ride_request.passenger_id}", {:ride_request_accepted, ride})

          {:ok, ride}

        {:error, failed_changeset} ->
           {:error, error_from_changeset(failed_changeset)}
      end
    end
  end

  def reject_ride_request(ride_request, driver) do
    # TODO
  end

  defp error_from_changeset(failed_changeset) do
    Enum.map(failed_changeset.errors, fn
      {:base, {message, _opts}} ->
        message

      {field, {message, _opts}} ->
        "#{field} #{message}"
    end)
    |> Enum.join(", ")
  end

  defp nearby_drivers(position, radius, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, radius)

    from(
      driver in Driver,
      where: fragment("? BETWEEN ? AND ?", driver.latitude, ^latitude_west, ^latitude_east),
      where: fragment("? BETWEEN ? AND ?", driver.longitude, ^longitude_south, ^longitude_north),
      order_by: fragment("pow(?, 2) + pow(?, 2)", driver.latitude, driver.longitude),
      limit: ^count
    )
    |> Repo.all()
  end

  def cancel_request(%Passenger{} = passenger) do
    result =
      passenger.ride_request
      |> RideRequest.changeset(%{cancelled_at: DateTime.utc_now()})
      |> update_changeset()

    with {:ok, _ride_request} <- result do
      {:ok,
        passenger
        |> Repo.preload(:ride_request, force: true)
        |> notify_of(:update)
      }
    end
  end

  defp insert_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.insert(changeset) do
      notify_of(record, :create)

      {:ok, record}
    end
  end

  defp update_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.update(changeset) do
      notify_of(record, :update)

      {:ok, record}
    end
  end

  defp notify_of(record, :update) do
    Phoenix.PubSub.broadcast(WhenToProcess.PubSub, "records", {:record_update, record})

    record
  end
  defp notify_of(record, :create) do
    Phoenix.PubSub.broadcast(WhenToProcess.PubSub, "records", {:record_created, record})

    record
  end
end
