defmodule WhenToProcess.Rides do
  @moduledoc """
  The Rides context.
  """

  import Ecto.Query, warn: false
  alias WhenToProcess.Repo

  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.Ride
  alias WhenToProcess.Rides.RideRequest

  @type uuid :: Ecto.UUID.t()
  @type position :: {float(), float()}

  @callback child_spec() :: Supervisor.child_spec() | nil
  @callback ready?() :: boolean()
  @callback reset() :: boolean()

  @callback list_drivers() :: [Driver.t()]

  @callback insert_changeset(Ecto.Changeset.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @callback update_changeset(Ecto.Changeset.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback count_drivers() :: integer()

  @callback get_driver!(uuid()) :: Driver.t() | nil

  @callback reload(term()) :: [term()]

  @callback reject_ride_request(RideRequest.t(), Driver.t()) :: {:ok, RideRequest.t()} | {:error, Ecto.Changeset.t()}

  @callback available_drivers(position(), integer()) :: [Driver.t()]
  @callback cancel_request(Passenger.t()) :: {:ok, Passenger.t()} | {:error, Ecto.Changeset.t()}

  def child_spec, do: implementation_module().child_spec()
  def ready?, do: implementation_module().ready?()

  def list_drivers, do: implementation_module().list_drivers()

  def create_driver(attrs) do
    attrs
    |> Driver.changeset_for_insert()
    |> implementation_module().insert_changeset()
  end

  def count_drivers do
    implementation_module().count_drivers()
  end

  def create_ride(attrs) do
    attrs
    |> Ride.changeset_for_insert()
    |> implementation_module().insert_changeset()
  end

  def create_passenger(attrs) do
    attrs
    |> Passenger.changeset_for_insert()
    |> implementation_module().insert_changeset()
  end

  def get_driver!(uuid), do: implementation_module().get_driver!(uuid)

  def reload(record), do: implementation_module().reload(record)

  def set_position(driver, new_position) do
    update_record(driver, %{position: new_position})
  end

  def go_online(driver) do
    update_record(driver, %{ready_for_passengers: true})
  end

  def no_more_passengers(driver) do
    update_record(driver, %{ready_for_passengers: false})
  end

  def reject_ride_request(ride_request, driver), do: implementation_module().reject_ride_request(ride_request, driver)

  # Exists to allow tests to reset state
  def reset(), do: implementation_module().reset()

  # Passenger actions

  # TODO: Test this function (available_drivers already tested)
  @spec request_ride(Passenger.t()) :: {:ok, Passenger.t()} | {:error, Ecto.Changeset.t()}
  def request_ride(passenger) do
    EctoRequireAssociations.ensure!(passenger, [:ride_request])

    result = update_record(passenger, %{ride_request: %{}})

    with {:ok, passenger} <- result do
      passenger
      |> position()
      |> implementation_module().available_drivers(3)
      |> Repo.all()
      |> Enum.each(fn driver ->
        # IO.puts("broadcasting to driver #{driver.id}")
        WhenToProcess.PubSub.broadcast("driver:#{driver.id}", {:new_ride_request, passenger.ride_request})
      end)

      {:ok, passenger}
    end
  end

  @spec accept_ride_request(RideRequest.t(), Driver.t()) :: {:ok, RideRequest.t()} | {:error, Ecto.Changeset.t()}
  def accept_ride_request(ride_request, driver) do
    ride_request = implementation_module().reload(ride_request)

    with :ok <- RideRequest.check_can_be_accepted(ride_request) do
      create_ride(%{driver_id: driver.id, ride_request_id: ride_request.id})
      |> case do
        {:ok, ride} ->
          # IO.puts("Broadcasting to passenger:#{ride_request.passenger_id}")
          WhenToProcess.PubSub.broadcast("passenger:#{ride_request.passenger_id}", {:ride_request_accepted, ride})

          {:ok, ride}

        {:error, failed_changeset} ->
           {:error, error_from_changeset(failed_changeset)}
      end
    end
  end

  def cancel_request(passenger), do: implementation_module().cancel_request(passenger)

  defp implementation_module do
    Application.get_env(:when_to_process, __MODULE__)[:implementation]
  end

  def list_passengers do
    Repo.all(Passenger)
  end

  def position(%{latitude: latitude, longitude: longitude}), do: {latitude, longitude}

  # For use internally
  # doesn't calculate a proper Euclidean distance, but rather it skips the sqrt
  # for something that can be used *only* for comparing how far apart positions are
  def sort_distance({latitude1, longitude1}, {latitude2, longitude2}) do
    :math.pow(latitude1 - latitude2, 2) + :math.pow(longitude1 - longitude2, 2)
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

  defp update_record(%schema_mod{} = record, attrs) do
    record
    |> schema_mod.changeset(attrs)
    |> implementation_module().update_changeset()
  end
end
