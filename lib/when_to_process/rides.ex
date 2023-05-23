defmodule WhenToProcess.Rides do
  @moduledoc """
  The Rides context.
  """

  import Ecto.Query, warn: false
  alias WhenToProcess.Repo

  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.RideRequest
  alias WhenToProcess.Locations

  @callback create_driver(Map.t()) :: {:ok, Driver.t()} | {:error, Ecto.Changeset.t()}
  @callback create_passenger(Map.t()) :: {:ok, Driver.t()} | {:error, Ecto.Changeset.t()}

  @callback set_position(Driver.t(), Locations.position()) ::
              {:ok, Driver.t()} | {:error, Ecto.Changeset.t()}
  @callback go_online(Driver.t()) :: {:ok, Driver.t()} | {:error, Ecto.Changeset.t()}
  @callback no_more_passengers(Driver.t()) :: {:ok, Driver.t()} | {:error, Ecto.Changeset.t()}
  @callback accept_ride_request(RideRequest.t(), Driver.t()) :: {:ok, RideRequest.t()} | {:error, Ecto.Changeset.t()}
  @callback reject_ride_request(RideRequest.t(), Driver.t()) :: {:ok, RideRequest.t()} | {:error, Ecto.Changeset.t()}

  @callback request_ride(Passenger.t()) :: {:ok, Passenger.t()} | {:error, Ecto.Changeset.t()}
  @callback cancel_request(Passenger.t()) :: {:ok, Passenger.t()} | {:error, Ecto.Changeset.t()}

  def create_driver(attrs), do: implementation_module().create_driver(attrs)
  def create_passenger(attrs), do: implementation_module().create_passenger(attrs)

  def set_position(driver, position), do: implementation_module().set_position(driver, position)

  # Driver actions
  def go_online(driver), do: implementation_module().go_online(driver)
  def no_more_passengers(driver), do: implementation_module().no_more_passengers(driver)
  def accept_ride_request(ride_request, driver), do: implementation_module().accept_ride_request(ride_request, driver)
  def reject_ride_request(ride_request, driver), do: implementation_module().reject_ride_request(ride_request, driver)

  # Passenger actions
  def request_ride(passenger), do: implementation_module().request_ride(passenger)
  def cancel_request(passenger), do: implementation_module().cancel_request(passenger)

  defp implementation_module do
    Application.get_env(:when_to_process, __MODULE__)[:implementation]
  end

  def list_drivers do
    Repo.all(Driver)
  end

  def list_passengers do
    Repo.all(Passenger)
  end

  def get_driver!(id), do: Repo.get!(Driver, id)

  def position(%{latitude: latitude, longitude: longitude}), do: {latitude, longitude}
end
