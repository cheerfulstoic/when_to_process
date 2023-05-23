defmodule WhenToProcessWeb.DriverLive do
  use WhenToProcessWeb, :live_view

  alias WhenToProcess.Rides

  @impl true
  def mount(_params, _session, socket) do
    {:ok, driver} =
      if connected?(socket) do
        case WhenToProcess.Locations.random_location(:stockholm) do
          {:ok, position} ->
            Rides.create_driver(%{name: Faker.Person.En.name(), position: position})

            # Handle error
        end
      else
        {:ok, nil}
      end

    driver = WhenToProcess.Repo.preload(driver, :current_ride)

    IO.inspect(driver, label: :driver)
    if driver do
      IO.puts("subscribing")
      Phoenix.PubSub.subscribe(WhenToProcess.PubSub, "driver:#{driver.id}")
    end

    {:ok,
     socket
     |> assign(:driver, driver)
     |> assign(:city_position, WhenToProcess.Locations.city_position(:stockholm))
     |> assign(:ride_request, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-window-keyup="key">
      <% {city_latitude, city_longitude} = @city_position %>
      <%= if @driver do %>
        <%= if @driver.ready_for_passengers do %>
          <.button phx-click="no-more-passengers">No More Passengers</.button>
        <% else %>
          <.button phx-click="go-online">Go Online</.button>
        <% end %>

        <%= if @ride_request do %>
          <.modal id="ride-request-modal" on_confirm={JS.push("accept")} on_cancel={JS.push("reject")} show={true}>
            <h1>Ride Request</h1>

            <p>Name: <%= @ride_request.passenger.name %></p>

            <:confirm>Accept</:confirm>
            <:cancel>Reject</:cancel>
          </.modal>
        <% end %>

        <pre class="whitespace-pre-wrap"><%= inspect(@ride_request) %></pre>

        <div
          class="px-4 mt-0 w-full h-[80vh]"
          phx-hook="Map"
          id="city"
          data-latitude={city_latitude}
          data-longitude={city_longitude}
          data-zoom="12"
        >
          <.driver_marker id="driver" driver={@driver} />

          <div id="map-container" phx-update="ignore" class="w-full h-full">
            <div
              id="the-map"
              class="z-0 overflow-hidden border border-gray-500 rounded-lg map w-full h-full"
            >
            </div>
          </div>
        </div>
        <pre class="whitespace-pre-wrap"><%= inspect(@driver) %></pre>
      <% else %>
        <p class="p-4 text-lg text-center text-orange-600">
          Sorry we are unable to display the map
        </p>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_params(%{}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Driver View")}
  end

  @impl true
  def handle_event("key", %{"key" => key}, socket) do
    IO.inspect(key, label: :key)

    direction =
      case key do
        "ArrowUp" -> :up
        "ArrowRight" -> :right
        "ArrowDown" -> :down
        "ArrowLeft" -> :left
        _ -> nil
      end

    driver = socket.assigns.driver

    if direction do
      bearing = WhenToProcess.Locations.bearing_for(direction)

      with {:ok, position} <-
             WhenToProcess.Locations.adjust({driver.latitude, driver.longitude}, bearing, 500) do
        Rides.set_position(driver, position)
      end
    else
      # Other key, ignore...
      {:ok, driver}
    end
    |> case do
      {:ok, driver} ->
        {:noreply,
         socket
         |> assign(:driver, driver)}

      {:error, error} ->
        {:noreply, update_socket_with_error(socket, error)}
    end
  end

  @impl true
  def handle_event("go-online", _params, socket) do
    case Rides.go_online(socket.assigns.driver) do
      {:ok, driver} ->
        {:noreply, assign(socket, :driver, driver)}

      {:error, error} ->
        {:noreply, update_socket_with_error(socket, error)}
    end
  end

  @impl true
  def handle_event("no-more-passengers", _params, socket) do
    case Rides.no_more_passengers(socket.assigns.driver) do
      {:ok, driver} ->
        {:noreply, assign(socket, :driver, driver)}

      {:error, error} ->
        {:noreply, update_socket_with_error(socket, error)}
    end
  end

  @impl true
  def handle_event("accept", %{}, socket) do
    ride = Rides.accept_ride_request(socket.assigns.ride_request, socket.assigns.driver)

    driver = WhenToProcess.Repo.preload(socket.assigns.driver, :current_ride, force: true)

    {:noreply,
      socket
      |> assign(:driver, driver)
      |> assign(:ride_request, nil)
      |> assign(:ride, ride)
    }
  end

  @impl true
  def handle_event("reject", %{}, socket) do
    ride = Rides.reject_ride_request(socket.assigns.ride_request, socket.assigns.driver)

    {:noreply, assign(socket, :ride_request, nil)}
  end

  @impl true
  def handle_info({:new_ride_request, ride_request}, socket) do
    ride_request = WhenToProcess.Repo.preload(ride_request, :passenger)

    {:noreply, assign(socket, :ride_request, ride_request)}
  end
end
