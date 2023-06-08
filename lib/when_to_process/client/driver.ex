defmodule WhenToProcess.Client.Driver do
  use Slipstream

  require Logger

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config)
  end

  @center_position {59.334591, 18.063240}

  @impl Slipstream
  def init(config) do
    bearing = WhenToProcess.Locations.random_bearing()
    distance = :rand.uniform(5_000)
    {:ok, start_position} = WhenToProcess.Locations.adjust(@center_position, bearing, distance)

    socket =
      config.slipstream_config
      |> connect!()
      |> assign(:driver_uuid, nil)
      |> assign(:last_bearing, bearing)
      |> assign(:position, start_position)
      |> assign(:ready_for_passengers, false)

    {:ok, socket, {:continue, :connect}}
  end

  @impl Slipstream
  def handle_continue(:connect, socket) do
    {:noreply, socket}
  end

  @impl Slipstream
  def handle_connect(socket) do
    case create_driver() do
      {:ok, driver_uuid} ->
        send_move()
        send_change_status()
        send_adjust_bearing()

        {:ok,
          socket
          |> assign(:driver_uuid, driver_uuid)
          |> join("driver:#{driver_uuid}")
        }

      {:error, _} ->
         {:stop, :create_driver_error, socket}
    end
  end

  defp create_driver do
    http_base = Application.get_env(:when_to_process, :client)[:http_base]

    opts = [timeout: 60_000, recv_timeout: 60_000]

    with {:error, _} <- HTTPoison.post("#{http_base}/drivers", "", [], opts) do
      HTTPoison.post("#{http_base}/drivers", "", [], opts)
    end
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok,
          body
          |> Jason.decode!()
          |> Map.get("uuid")
        }

      {:error, _} = error ->
        error
    end
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    case reconnect(socket) do
      {:ok, socket} -> {:ok, socket}
      {:error, reason} -> {:stop, reason, socket}
    end
  end

  @impl Slipstream
  def handle_topic_close(topic, _reason, socket) do
    {:ok, _socket} = rejoin(socket, topic)
  end

  @impl Slipstream
  def handle_info(:move, %{assigns: %{driver_uuid: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_info(:move, socket) do
    # Logger.info("move")
    driver_uuid = socket.assigns.driver_uuid
    {latitude, longitude} = socket.assigns.position

    bearing = WhenToProcess.Locations.standardize_bearing(socket.assigns.last_bearing + (:rand.uniform() * 0.3) - 0.15)

    distance = :rand.uniform(400)
    {:ok, {new_latitude, new_longitude}} = WhenToProcess.Locations.adjust({latitude, longitude}, bearing, distance)

    case push(socket, "driver:#{driver_uuid}", "update_location", %{latitude: new_latitude, longitude: new_longitude}) do
      {:ok, _} ->
        send_move()

        {:noreply,
          socket
          |> assign(:position, {new_latitude, new_longitude})
          |> assign(:last_bearing, bearing)
        }
      other ->
        IO.inspect(other)
        IO.puts("COULD NOT PUSH UPDATE_LOCATION!!!")

        {:noreply, socket}
    end

  end

  def handle_info(:change_status, socket) do
    # Logger.info("change_status")
    ready_for_passengers = !socket.assigns.ready_for_passengers

    send_change_status()

    driver_uuid = socket.assigns.driver_uuid

    message = if(ready_for_passengers, do: "go_online", else: "no_more_passengers")

    case push(socket, "driver:#{driver_uuid}", message, nil) do
      {:ok, _} ->
        {:noreply,
          socket
          |> assign(:ready_for_passengers, ready_for_passengers)
        }

      _ ->
        IO.puts("COULD NOT PUSH GO_ONLINE!!!")

        {:noreply, socket}
    end

  end

  def handle_info(:adjust_bearing, socket) do
    send_adjust_bearing()

    {:noreply, assign(socket, :last_bearing, WhenToProcess.Locations.random_bearing())}
  end

  @move_delay 5_000
  @change_status_delay 60_000
  @adjust_bearing_delay 20_000

  defp send_move do
    Process.send_after(self(), :move, random_from(@move_delay))
  end

  defp send_change_status do
    Process.send_after(self(), :change_status, random_from(@change_status_delay))
  end

  defp send_adjust_bearing do
    Process.send_after(self(), :adjust_bearing, random_from(@adjust_bearing_delay))
  end

  defp random_from(delay) do
    floor = div(delay, 2)
    :rand.uniform(delay - floor) + floor
  end
end

