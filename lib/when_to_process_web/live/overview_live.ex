defmodule WhenToProcessWeb.OverviewLive do
  use WhenToProcessWeb, :live_view

  alias WhenToProcess.Rides

  alias WhenToProcessWeb.Components

  @impl true
  def mount(_params, _session, socket) do
    drivers =
      Rides.list(Rides.Driver)
      |> WhenToProcess.Repo.preload(:current_ride)

    passengers =
      Rides.list(Rides.Passenger)
      |> WhenToProcess.Repo.preload(:ride_request)

    Phoenix.PubSub.subscribe(WhenToProcess.PubSub, "records")

    {:ok,
     socket
     |> stream(:drivers, drivers, dom_id: &"driver-#{&1.uuid}")
     |> stream(:passengers, passengers, dom_id: &"passenger-#{&1.uuid}")
     |> assign(:city_position, WhenToProcess.Locations.city_position(:stockholm))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <% {city_latitude, city_longitude} = @city_position %>
      <div
        phx-hook="Map"
        class="px-4 mt-0 w-full h-[80vh]"
        id="city"
        data-latitude={city_latitude}
        data-longitude={city_longitude}
        data-zoom="12"
      >
        <div id="markers" phx-update="stream">
          <.live_component
            :for={{dom_id, driver} <- @streams.drivers}
            module={Components.Marker}
            id={dom_id}
            record={driver}
          />

          <.live_component
            :for={{dom_id, passenger} <- @streams.passengers}
            module={Components.Marker}
            id={dom_id}
            record={passenger}
          />
        </div>

        <div id="map-container" phx-update="ignore" class="w-full h-full">
          <div
            id="leaflet-map"
            class="z-0 overflow-hidden border border-gray-500 rounded-lg map w-full h-full"
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:record_updated, record}, socket) do
    # IO.puts("OverviewLive - record_updated")

    record = preload_for(record)

    case stream_key(record) do
      nil ->
        {:noreply, socket}

      stream_key ->
        {:noreply,
         socket
         |> stream_insert(stream_key, record, at: -1)}
    end
  end

  @impl true
  def handle_info({:record_created, record}, socket) do
    # IO.puts("OverviewLive - record_created")

    case stream_key(record) do
      nil ->
        {:noreply, socket}

      stream_key ->
        record = preload_for(record)

        {:noreply, stream_insert(socket, stream_key, record, at: 0)}
    end
  end

  def preload_for(%Rides.Driver{} = driver) do
    WhenToProcess.Repo.preload(driver, :current_ride)
  end

  def preload_for(%Rides.Passenger{} = passenger) do
    WhenToProcess.Repo.preload(passenger, :ride_request)
  end

  def preload_for(record), do: record

  def stream_key(%Rides.Driver{}), do: :drivers
  def stream_key(%Rides.Passenger{}), do: :passengers
  def stream_key(_), do: nil
end
