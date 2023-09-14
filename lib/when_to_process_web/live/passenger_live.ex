defmodule WhenToProcessWeb.PassengerLive do
  use WhenToProcessWeb, :live_view

  alias WhenToProcess.Rides

  alias WhenToProcessWeb.Components

  @impl true
  def mount(_params, _session, socket) do
    # IO.inspect(socket.assigns, label: :da_assigns)
    {:ok, passenger} =
      if connected?(socket) do
        case WhenToProcess.Locations.random_location(:stockholm) do
          {:ok, position} ->
            Rides.create(Rides.Passenger, %{name: Faker.Person.En.name(), position: position})
            # Handle error
        end
      else
        {:ok, nil}
      end

    passenger = WhenToProcess.Repo.preload(passenger, [:ride_request, current_ride: :driver])

    if passenger do
      # IO.puts("PassengerLive subscribing")
      Phoenix.PubSub.subscribe(WhenToProcess.PubSub, "passenger:#{passenger.id}")
    end

    {:ok,
     socket
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

        <%= if @passenger.current_ride do %>
          <strong><%= @passenger.current_ride.driver.name %></strong>
          has accepted your request for a ride.
        <% end %>
        <div
          class="px-4 mt-0 w-full h-[80vh]"
          phx-hook="Map"
          id="city"
          data-latitude={city_latitude}
          data-longitude={city_longitude}
          data-zoom="12"
        >
          <.live_component
            :if={@passenger.current_ride}
            module={Components.Marker}
            id="ride"
            record={@passenger.current_ride}
          />

          <.live_component
            :if={!@passenger.current_ride}
            module={Components.Marker}
            id="passenger"
            record={@passenger}
          />

          <div id="map-container" phx-update="ignore" class="w-full h-full">
            <div
              id="leaflet-map"
              class="z-0 overflow-hidden border border-gray-500 rounded-lg map w-full h-full"
            >
            </div>
          </div>
        </div>
        <pre class="whitespace-pre-wrap"><%= inspect(@passenger.current_ride) %></pre>
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
    case socket.assigns.passenger.ride_request do
      nil ->
        raise "An attempt was made to cancel a ride request when one was not set"

      ride_request ->
        case Rides.cancel_request(ride_request) do
          {:ok, passenger} ->
            {:noreply, assign(socket, :passenger, passenger)}

          {:error, error} ->
            {:noreply, update_socket_with_error(socket, error)}
        end
    end
  end

  @impl true
  def handle_info({:ride_request_accepted, _ride_request}, socket) do
    passenger =
      socket.assigns.passenger
      |> WhenToProcess.Repo.preload([current_ride: :driver], force: true)

    # IO.puts("Subscribing to driver updates for ##{passenger.current_ride.driver.id}")
    Phoenix.PubSub.subscribe(
      WhenToProcess.PubSub,
      "records:driver:#{passenger.current_ride.driver.id}"
    )

    {:noreply, assign(socket, :passenger, passenger)}
  end

  def handle_info({:record_created, _}, socket), do: {:noreply, socket}

  # Should there be targetted broadcasts for just the passenger?
  def handle_info(
        {:record_updated, %Rides.Passenger{id: passenger_id} = updated_passenger},
        %{assigns: %{passenger: %{id: passenger_id}}} = socket
      ) do
    # IO.inspect(updated_passenger, label: :PassengerLive_updated_passenger)
    {:noreply, assign(socket, :passenger, updated_passenger)}
  end

  def handle_info(
        {:record_updated, %Rides.Driver{id: driver_id} = updated_driver},
        %{assigns: %{passenger: %{current_ride: %{driver: %{id: driver_id}}} = passenger}} =
          socket
      ) do
    # IO.inspect(updated_driver, label: :PassengerLive_updated_driver)
    {:noreply, assign(socket, :passenger, put_in(passenger.current_ride.driver, updated_driver))}
  end

  def handle_info({:record_updated, _}, socket) do
    # IO.inspect("PassengerLive: update message")
    {:noreply, socket}
  end
end
