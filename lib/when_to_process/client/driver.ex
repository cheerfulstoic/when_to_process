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
      |> assign(:uuid, nil)
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
      {:ok, uuid} ->
        send_move()
        send_change_status()
        send_adjust_bearing()

        {:ok,
         socket
         |> assign(:uuid, uuid)
         |> join("driver:#{uuid}")}

      # {:error, %HTTPoison.Error{reason: :eaddrnotavail}} ->

      {:error, value} ->
        IO.inspect(value, label: :error_value)
        {:stop, {:create_driver_error, value}, socket}
    end
  end

  defp create_driver do
    http_base = Application.get_env(:when_to_process, :client)[:http_base]

    opts = [connect_timeout: 60_000, checkout_timeout: 60_000, timeout: 60_000, recv_timeout: 60_000]

    with {:error, _} <- HTTPoison.post("#{http_base}/drivers", "", [], opts) do
      IO.puts("Retrying...")
      Process.sleep(5_000)
      HTTPoison.post("#{http_base}/drivers", "", [], opts)
    end
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok,
         body
         |> Jason.decode!()
         |> Map.get("uuid")}

      {:ok, %HTTPoison.Response{body: body}} ->
        {:error, body}

      {:error, _} = error ->
        error
    end
  end

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    IO.puts("DISCONNECT: #{inspect(reason)}")

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
  def handle_info(:move, %{assigns: %{uuid: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_info(:move, socket) do
    # Logger.info("move")
    uuid = socket.assigns.uuid
    {latitude, longitude} = socket.assigns.position

    bearing =
      WhenToProcess.Locations.standardize_bearing(
        socket.assigns.last_bearing + :rand.uniform() * 0.3 - 0.15
      )

    distance = :rand.uniform(400)

    {:ok, {new_latitude, new_longitude}} =
      WhenToProcess.Locations.adjust({latitude, longitude}, bearing, distance)

    case push_handled(socket, "driver:#{uuid}", "update_location", %{
           latitude: new_latitude,
           longitude: new_longitude
         }) do
      {:ok, socket} ->
        send_move()

        {:noreply,
         socket
         |> assign(:position, {new_latitude, new_longitude})
         |> assign(:last_bearing, bearing)}

      {:error, _message} ->
        {:noreply, socket}
    end
  end

  def handle_info(:change_status, socket) do
    # Logger.info("change_status")
    ready_for_passengers = !socket.assigns.ready_for_passengers

    send_change_status()

    uuid = socket.assigns.uuid

    # http_base = Application.get_env(:when_to_process, :client)[:http_base]

    # {:ok, _} = HTTPoison.get("#{http_base}/drivers/wait")

    message = if(ready_for_passengers, do: "go_online", else: "no_more_passengers")

    case push_handled(socket, "driver:#{uuid}", message, nil) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:ready_for_passengers, ready_for_passengers)}

      {:error, _message} ->
        {:noreply, socket}
    end
  end

  def handle_info(:adjust_bearing, socket) do
    send_adjust_bearing()

    {:noreply, assign(socket, :last_bearing, WhenToProcess.Locations.random_bearing())}
  end

  def push_handled(socket, topic, event, params, timeout \\ 5_000) do
    case push(socket, topic, event, params, timeout) do
      {:ok, _} ->
        {:ok, socket}

      {:error, :not_joined} ->
        {:ok, socket} = rejoin(socket, topic)

        {:ok, socket}

      {:error, message} = error ->
        IO.puts("COULD NOT PUSH #{event} to #{topic}!!! #{inspect(message)}")

        error
    end
  end

  @move_delay 16_000
  @change_status_delay 40_000
  @adjust_bearing_delay 24_000

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
