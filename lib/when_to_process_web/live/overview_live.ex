defmodule WhenToProcessWeb.OverviewLive do
  use WhenToProcessWeb, :live_view

  alias WhenToProcess.Rides

  @impl true
  def mount(_params, _session, socket) do
    drivers =
      Rides.list_drivers()
      |> WhenToProcess.Repo.preload(:current_ride)
    passengers =
      Rides.list_passengers()
      |> WhenToProcess.Repo.preload(:ride_request)

    Phoenix.PubSub.subscribe(WhenToProcess.PubSub, "records")

    {:ok,
     socket
     |> stream(:drivers, drivers)
     |> stream(:passengers, passengers)
     |> assign(:city_position, WhenToProcess.Locations.city_position(:stockholm))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <% {city_latitude, city_longitude} = @city_position %>
      <div
        phx-update="stream"
        class="px-4 mt-0 w-full h-[80vh]"
        phx-hook="Map"
        id="city"
        data-latitude={city_latitude}
        data-longitude={city_longitude}
        data-zoom="12"
      >
        <.driver_marker :for={{dom_id, driver} <- @streams.drivers} id={dom_id} driver={driver} />
        <.passenger_marker
          :for={{dom_id, passenger} <- @streams.passengers}
          id={dom_id}
          passenger={passenger}
        />

        <div id="map-container" phx-update="ignore" class="w-full h-full">
          <div
            id="the-map"
            class="z-0 overflow-hidden border border-gray-500 rounded-lg map w-full h-full"
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:record_update, record}, socket) do
    IO.puts("Record update!")
    IO.inspect(record)

    case stream_key(record) do
      nil ->
        {:noreply, socket}

      stream_key ->
        {:noreply,
         socket
         |> stream_delete(stream_key, record)
         |> stream_insert(stream_key, record, at: -1)}
    end
  end

  @impl true
  def handle_info({:record_created, record}, socket) do
    IO.puts("Record created!")
    IO.inspect(record)

    case stream_key(record) do
      nil ->
        {:noreply, socket}

      stream_key ->
        record = preload_for(record)

        {:noreply, stream_insert(socket, stream_key, record, at: 0)}
    end
  end

  def preload_for(%Rides.Passenger{} = passenger) do
    WhenToProcess.Repo.preload(passenger, :ride_request)
  end
  def preload_for(record), do: record

  def stream_key(%Rides.Driver{}), do: :drivers
  def stream_key(%Rides.Passenger{}), do: :passengers
  def stream_key(_), do: nil
end
