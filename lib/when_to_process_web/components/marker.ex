defmodule WhenToProcessWeb.Components.Marker do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_component
  use Phoenix.LiveComponent

  alias WhenToProcess.Rides

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :record, nil)}
  end

  @impl true
  def update(%{record: record}, socket) do
    new_assigns =
      case record do
        %Rides.Driver{} = driver ->
          EctoRequireAssociations.ensure!(driver, [:current_ride])

          %{
            type: "driver",
            id: driver.uuid,
            latitude: driver.latitude,
            longitude: driver.longitude,
            metadata: %{ready_for_passengers: driver.ready_for_passengers, engaged: !!driver.current_ride}
          }

        %Rides.Passenger{} = passenger ->
          EctoRequireAssociations.ensure!(passenger, [:ride_request])

          %{
            type: "passenger",
            id: passenger.uuid,
            latitude: passenger.latitude,
            longitude: passenger.longitude,
            metadata: %{ride_requested: !!passenger.ride_request}
          }

        %Rides.Ride{} = ride ->
          EctoRequireAssociations.ensure!(ride, [:driver])

          %{
            type: "ride",
            id: ride.id,
            latitude: ride.driver.latitude,
            longitude: ride.driver.longitude,
            metadata: %{engaged: true},
          }
      end

    {:ok, assign(socket, new_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        id={"#{@type}-#{@id}"}
        phx-hook="Marker"
        data-type={@type}
        data-latitude={@latitude}
        data-longitude={@longitude}
        data-metadata={Jason.encode!(@metadata)}
      >
      </div>
    </div>
    """
  end

end


