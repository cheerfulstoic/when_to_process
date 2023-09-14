defmodule WhenToProcessWeb.PassengerController do
  use WhenToProcessWeb, :controller

  alias WhenToProcess.Rides

  def create(conn, _params) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, passenger} = create_new_passenger()

    json(conn, %{uuid: passenger.uuid})
  end

  defp create_new_passenger do
    case WhenToProcess.Locations.random_location(:stockholm) do
      {:ok, position} ->
        Rides.create(Rides.Passenger, %{name: Faker.Person.En.name(), position: position})
    end
  end
end
