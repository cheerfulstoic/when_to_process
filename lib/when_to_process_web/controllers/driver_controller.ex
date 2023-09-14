defmodule WhenToProcessWeb.DriverController do
  use WhenToProcessWeb, :controller

  alias WhenToProcess.Rides

  def create(conn, _params) do
    # WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, driver} = create_new_driver()

    json(conn, %{uuid: driver.uuid})
  end

  def setup_drivers(conn, %{"count" => count}) do
    # WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    IO.inspect(count, label: :count)
    drivers = Rides.list(Rides.Driver)

    count = String.to_integer(count)

    drivers =
      if length(drivers) < count do
        drivers ++
          Enum.map(length(drivers)..count, fn _ ->
            {:ok, driver} = create_new_driver()

            driver
          end)
      else
        drivers
      end

    json(conn, Enum.map(drivers, &%{uuid: &1.uuid}))
  end

  # Test action
  def wait(conn, %{}) do
    Process.sleep(2_000)

    json(conn, %{})
  end

  def test(conn, %{}) do
    limit = :erlang.system_info(:port_limit)

    json(conn, %{limit: limit})
  end

  defp create_new_driver do
    case WhenToProcess.Locations.random_location(:stockholm) do
      {:ok, position} ->
        Rides.create(Rides.Driver, %{name: Faker.Person.En.name(), position: position})
    end
  end
end
