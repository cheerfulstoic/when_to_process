defmodule WhenToProcess.Factory do
  use ExMachina.Ecto, repo: WhenToProcess.Repo

  alias WhenToProcess.Rides

  def driver_factory do
    %Rides.Driver{
      name: Faker.Person.En.name()
    }
  end

  def passenger_factory do
    %Rides.Passenger{
      name: Faker.Person.En.name()
    }
  end

  def ride_request_factory do
    %Rides.RideRequest{
      passenger: build(:passenger)
    }
  end

  def ride_factory do
    %Rides.Ride{
      driver: build(:driver),
      ride_request: build(:ride_request)
    }
  end
end
