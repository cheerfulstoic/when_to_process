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
    case craete_passenger() do
      {:ok, uuid} ->
        # send_move()
        # send_change_status()
        # send_adjust_bearing()

        {:ok,
          socket
          |> assign(:uuid, uuid)
          |> join("passenger:#{uuid}")
        }

      {:error, value} ->
        IO.inspect(value, label: :error_value)
        {:stop, :create_passenger_error, socket}
    end
  end

  defp craete_passenger do
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

end

