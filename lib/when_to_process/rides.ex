defmodule WhenToProcess.Rides do
  @moduledoc """
  The Rides context.
  """

  import Ecto.Query, warn: false

  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.Ride
  alias WhenToProcess.Rides.RideRequest

  @type uuid :: Ecto.UUID.t()
  @type position :: {float(), float()}

  def child_specs do
    state_implementation_modules()
    |> Enum.flat_map(fn module ->
      [module.state_child_spec(Driver), module.state_child_spec(Passenger)]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end
  def ready?() do
    state_implementation_modules()
    |> Enum.all?(fn module ->
      module.ready?(Driver) &&
      module.ready?(Passenger)
    end)
  end

  def list(module), do: global_state_implementation_module().list(module)

  def create(module, attrs \\ %{}) do
    attrs
    |> module.changeset_for_insert()
    |> then(fn changeset ->
      state_implementation_modules()
      |> Enum.map(& &1.insert_changeset(changeset))
      |> List.last()
    end)
  end

  def count(module) do
    global_state_implementation_module().count(module)
  end

  def get!(module, uuid) do
    with nil <- get(module, uuid) do
      raise "Could not found #{module} `#{uuid}`"
    end
  end

  def get(module, uuid) do
    individual_state_implementation_module().get(module, uuid)
  end

  def reload(record), do: global_state_implementation_module().reload(record)

  def set_position(driver, new_position) do
    update_record(driver, %{position: new_position})
  end

  def go_online(driver) do
    update_record(driver, %{ready_for_passengers: true})
  end

  def no_more_passengers(driver) do
    update_record(driver, %{ready_for_passengers: false})
  end

  def reject_ride_request(ride_request, driver), do: global_state_implementation_module().reject_ride_request(ride_request, driver)

  # Exists to allow tests to reset state
  def reset() do
    global_state_implementation_module().reset(Driver)
    global_state_implementation_module().reset(Passenger)
  end

  # Passenger actions

  @spec request_ride(Passenger.t()) :: {:ok, Passenger.t()} | {:error, Ecto.Changeset.t()}
  def request_ride(passenger) do
    EctoRequireAssociations.ensure!(passenger, [:ride_request])

    result = update_record(passenger, %{ride_request: %{}})

    with {:ok, passenger} <- result do
      global_state_implementation_module().list_nearby(Driver, position(passenger), 2_000, (& &1.ready_for_passengers), 3)
      |> Enum.each(fn driver ->
        # IO.puts("broadcasting to driver #{driver.id}")
        WhenToProcess.PubSub.broadcast("driver:#{driver.id}", {:new_ride_request, passenger.ride_request})
      end)

      {:ok, passenger}
    end
  end

  @spec accept_ride_request(RideRequest.t(), Driver.t()) :: {:ok, RideRequest.t()} | {:error, Ecto.Changeset.t()}
  def accept_ride_request(ride_request, driver) do
    ride_request = reload(ride_request)

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

  def cancel_request(passenger) do
    case global_state_implementation_module().cancel_request(passenger) do
      {:ok, updated_ride_request} ->
        # Possible race condition?
        Map.put(passenger, :ride_request, updated_ride_request)
        |> WhenToProcess.PubSub.broadcast_record_update()

      {:error, failed_changeset} ->
         {:error, error_from_changeset(failed_changeset)}
    end
  end

  def create_ride(attrs) do
    attrs
    |> Ride.changeset_for_insert()
    |> global_state_implementation_module().insert_changeset()
  end

  # Just for use internally
  def _global_state_implementation_module do
    global_state_implementation_module()
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
    |> then(fn changeset ->
      Enum.map(state_implementation_modules(), fn module ->
        module.update_changeset(changeset)
      end)
      |> List.last()
    end)
  end

  defp global_state_implementation_module do
    config()[:global_state_implementation_module]
  end

  defp individual_state_implementation_module do
    config()[:individual_state_implementation_module]
  end

  defp state_implementation_modules do
    # It's important that the `global` module comes before the individual module
    # The individual module may fetch the record from the global state, and so it needs to be there
    Enum.uniq([global_state_implementation_module(), individual_state_implementation_module()])
  end

  defp config do
    Application.get_env(:when_to_process, __MODULE__)
  end
end
