defmodule WhenToProcessWeb.PassengerChannel do
  use WhenToProcessWeb, :channel

  alias WhenToProcess.Rides
  @impl true
  def join("passenger:" <> uuid, _payload, socket) do
    # IO.inspect("GOT A PASSENGER JOIN REQUEST!  #{uuid}")

    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    passenger =
      Rides.get!(Rides.Passenger, uuid)
      |> WhenToProcess.Repo.preload([:ride_request])

    {:ok, assign(socket, :passenger, passenger)}
  end

  @impl true
  def handle_in("request_ride", _, socket) do
    case Rides.request_ride(socket.assigns.passenger) do
      {:ok, passenger} ->
        {:reply, :ok, assign(socket, :passenger, passenger)}

      {:error, _} ->
        {:reply, {:error, %{}}, socket}
    end
  end

  @impl true
  def handle_in("cancel_ride_request", _, socket) do
    case socket.assigns.passenger.ride_request do
      nil ->
        raise "An attempt was made to cancel a ride request when one was not set"

      ride_request ->
        case Rides.cancel_request(ride_request) do
          {:ok, updated_ride_request} ->
            {
              :reply,
              :ok,
              assign(
                socket,
                :passenger,
                Map.put(socket.assigns.passenger, :ride_request, updated_ride_request)
              )
            }

          {:error, _} ->
            {:reply, {:error, %{}}, socket}
        end
    end
  end
end
