defmodule WhenToProcessWeb.DriverChannel do
  use WhenToProcessWeb, :channel

  alias WhenToProcess.Rides
  # alias WhenToProcessWeb.Presence

  @impl true
  def join("driver:" <> driver_uuid, _payload, socket) do
    # IO.inspect("GOT A JOIN REQUEST!  #{driver_uuid}")
    send(self(), :after_join)

    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, assign(socket, :driver, Rides.get!(Rides.Driver, driver_uuid))}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("update_location", %{"latitude" => latitute, "longitude" => longitude}, socket) do
    case Rides.set_position(socket.assigns.driver, {latitute, longitude}) do
      {:ok, driver} -> {:reply, :ok, assign(socket, :driver, driver)}
      {:error, _} -> {:reply, {:error, %{}}, socket}
    end
  end

  @impl true
  def handle_in("go_online", _, socket) do
    case Rides.go_online(socket.assigns.driver) do
      {:ok, driver} -> {:reply, :ok, assign(socket, :driver, driver)}
      {:error, _} -> {:reply, {:error, %{}}, socket}
    end
  end

  @impl true
  def handle_in("no_more_passengers", _, socket) do
    case Rides.no_more_passengers(socket.assigns.driver) do
      {:ok, driver} -> {:reply, :ok, assign(socket, :driver, driver)}
      {:error, _} -> {:reply, {:error, %{}}, socket}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # {:ok, _} = Presence.track(socket, "driver_channel_connections", %{})

    # IO.inspect(Presence.list(socket), label: :presence_list)

    {:noreply, socket}
  end

  # # It is also common to receive messages from the client and
  # # broadcast to everyone in the current topic (driver:lobby).
  # @impl true
  # def handle_in("shout", payload, socket) do
  #   broadcast(socket, "shout", payload)

  #   {:noreply, socket}
  # end

  # # Add authorization logic here as required.
  # defp authorized?(_payload) do
  #   true
  # end
end
