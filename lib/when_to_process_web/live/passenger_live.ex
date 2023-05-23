defmodule WhenToProcessWeb.PassengerLive do
  use WhenToProcessWeb, :live_view

  alias WhenToProcess.Rides

  @impl true
  def mount(_params, _session, socket) do
    {:ok, passenger} =
      if connected?(socket) do
        case WhenToProcess.Locations.random_location(:stockholm) do
          {:ok, position} ->
            Rides.create_passenger(%{name: Faker.Person.En.name(), position: position})
            # Handle error
        end
      else
        {:ok, nil}
      end

    passenger = WhenToProcess.Repo.preload(passenger, [:ride_request, current_ride: :driver])

    if passenger do
      IO.puts("subscribing")
      Phoenix.PubSub.subscribe(WhenToProcess.PubSub, "passenger:#{passenger.id}")
    end

    {:ok,
     socket
     |> assign(:ride, nil)
     |> assign(:passenger, passenger)
     |> assign(:city_position, WhenToProcess.Locations.city_position(:stockholm))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <% {city_latitude, city_longitude} = @city_position %>
      <%= if @passenger do %>
        <%= if @passenger.ride_request == nil do %>
          <.button phx-click="request-ride">Request Ride</.button>
        <% else %>
          <.button phx-click="cancel-request">Cancel Request</.button>
        <% end %>

        <div
          class="px-4 mt-0 w-full h-[80vh]"
          phx-hook="Map"
          id="city"
          data-latitude={city_latitude}
          data-longitude={city_longitude}
          data-zoom="12"
        >
          <.passenger_marker passenger={@passenger} />
          <.driver_marker :if={@passenger.current_ride} passenger={@passenger.current_ride.driver} />

          <div id="map-container" phx-update="ignore" class="w-full h-full">
            <div
              id="the-map"
              class="z-0 overflow-hidden border border-gray-500 rounded-lg map w-full h-full"
            >
            </div>
          </div>
        </div>
        <pre class="whitespace-pre-wrap"><%= inspect(@passenger) %></pre>
        <pre class="whitespace-pre-wrap"><%= inspect(@ride) %></pre>
      <% else %>
        <p class="p-4 text-lg text-center text-orange-600">
          Sorry we are unable to display the map
        </p>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("request-ride", _params, socket) do
    case Rides.request_ride(socket.assigns.passenger) do
      {:ok, passenger} ->
        {:noreply, assign(socket, :passenger, passenger)}

      {:error, error} ->
        {:noreply, update_socket_with_error(socket, error)}
    end
  end

  @impl true
  def handle_event("cancel-request", _params, socket) do
    case Rides.cancel_request(socket.assigns.passenger) do
      {:ok, passenger} ->
        {:noreply, assign(socket, :passenger, passenger)}

      {:error, error} ->
        {:noreply, update_socket_with_error(socket, error)}
    end
  end

  @impl true
  def handle_info({:ride_request_accepted, _ride}, socket) do
    passenger =
      socket.assigns.passenger
      |> WhenToProcess.Repo.preload([current_ride: :driver], force: true)

    {:noreply, assign(socket, :passenger, passenger)}
  end
end
