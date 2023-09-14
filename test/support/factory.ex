defmodule WhenToProcess.Factory do
  use ExMachina.Ecto, repo: WhenToProcess.Repo

  alias WhenToProcess.Rides

  def driver_factory do
    %Rides.Driver{
      uuid: Ecto.UUID.generate(),
      name: Faker.Person.En.name(),
      latitude: generate_latitude(),
      longitude: generate_longitude()
    }
  end

  def passenger_factory do
    %Rides.Passenger{
      uuid: Ecto.UUID.generate(),
      name: Faker.Person.En.name(),
      latitude: generate_latitude(),
      longitude: generate_longitude()
    }
  end

  def ride_request_factory do
    %Rides.RideRequest{
      uuid: Ecto.UUID.generate(),
      created_ride: nil,
      passenger: build(:passenger)
    }
  end

  def ride_factory do
    %Rides.Ride{
      driver: build(:driver),
      ride_request: build(:ride_request)
    }
  end

  defp generate_latitude do
    :rand.uniform() * 180 - 90
  end

  defp generate_longitude do
    :rand.uniform() * 360 - 180
  end
end
