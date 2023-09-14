defmodule WhenToProcessWeb.CustomHelpers do
  use Phoenix.Component

  alias WhenToProcess.Rides

  attr :id, :string, required: true
  attr :driver, Rides.Driver, required: true

  def driver_marker(assigns) do
    EctoRequireAssociations.ensure!(assigns.driver, [:current_ride])

    ~H"""
    <div
      class="marker"
      id={"driver-#{@driver.id}"}
      data-type="driver"
      data-latitude={@driver.latitude}
      data-longitude={@driver.longitude}
      data-ready-for-passengers={inspect(@driver.ready_for_passengers)}
      data-engaged={inspect(!!@driver.current_ride)}
    >
    </div>
    """
  end

  attr :id, :string, required: true
  attr :ride, Rides.Ride, required: true

  def ride_marker(assigns) do
    EctoRequireAssociations.ensure!(assigns.ride, :driver)

    assigns
    |> Map.put(:driver, Map.put(assigns.ride.driver, :current_ride, assigns.ride))
    |> driver_marker()
  end

  def passenger_marker(assigns) do
    EctoRequireAssociations.ensure!(assigns.passenger, [:ride_request])

    ~H"""
    <div
      class="marker"
      id={"passenger-#{@passenger.id}"}
      data-type="passenger"
      data-latitude={@passenger.latitude}
      data-longitude={@passenger.longitude}
      data-ride-requested={inspect(!!@passenger.ride_request)}
    >
    </div>
    """
  end

  def update_socket_with_error(socket, message) when is_binary(message) do
    Phoenix.LiveView.put_flash(socket, :error, message)
  end

  def update_socket_with_error(socket, %Ecto.Changeset{} = changeset) do
    IO.inspect(changeset)
    Phoenix.LiveView.put_flash(socket, :error, "CHANGESET ERROR - TODO")
  end
end
