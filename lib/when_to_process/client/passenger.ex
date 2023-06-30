defmodule WhenToProcess.Client.Passenger do
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
    {:ok, position} = WhenToProcess.Locations.adjust(@center_position, bearing, distance)

    socket =
      config.slipstream_config
      |> connect!()
      |> assign(:uuid, nil)
      |> assign(:position, position)
      # Possible states: no_ride_needed, ride_requested, waiting_for_pickup, riding
      |> assign(:state, :no_ride_needed)

    {:ok, socket, {:continue, :connect}}
  end

  @impl Slipstream
  def handle_continue(:connect, socket) do
    {:noreply, socket}
  end

  @impl Slipstream
  def handle_connect(socket) do
    case create_passenger() do
      {:ok, uuid} ->
        send_toggle_ride_request()
        # send_change_status()
        # send_adjust_bearing()

        {:ok,
          socket
          |> assign(:uuid, uuid)
          |> assign(:current_status, :idle)
          |> join("passenger:#{uuid}")
        }

      {:error, value} ->
        IO.inspect(value, label: :error_value)
        {:stop, :create_passenger_error, socket}
    end
  end

  defp create_passenger do
    http_base = Application.get_env(:when_to_process, :client)[:http_base]

    opts = [timeout: 60_000, recv_timeout: 60_000]

    with {:error, _} <- HTTPoison.post("#{http_base}/passengers", "", [], opts) do
      HTTPoison.post("#{http_base}/passengers", "", [], opts)
    end
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok,
          body
          |> Jason.decode!()
          |> Map.get("uuid")
        }

      {:ok, %HTTPoison.Response{body: body}} ->
        {:error, body}

      {:error, _} = error ->
        error
    end
  end

  def handle_info(:toggle_ride_request, socket) do
    # Logger.info("toggle_ride_request")

    uuid = socket.assigns.uuid

    {message_to_send, next_state_on_success} =
      case socket.assigns.current_status do
        :idle ->
          {"request_ride", :ride_requested}

        :ride_requested ->
          {"cancel_ride_request", :idle}
      end

    IO.puts("Sending #{message_to_send}")
    case push_handled(socket, "passenger:#{uuid}", message_to_send, %{}) do
      {:ok, socket} ->
        IO.puts("#{message_to_send} SUCCESS")

        send_toggle_ride_request()

        {:noreply, assign(socket, :current_status, next_state_on_success)}

      {:error, _} ->
        {:noreply, socket}
    end
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

  # @move_delay 8_000
  # @change_status_delay 20_000
  # @adjust_bearing_delay 12_000
  @toggle_ride_request_delay 12_000

  defp send_toggle_ride_request do
    Process.send_after(self(), :toggle_ride_request, random_from(@toggle_ride_request_delay))
  end

  defp random_from(delay) do
    floor = div(delay, 2)
    :rand.uniform(delay - floor) + floor
  end
end

