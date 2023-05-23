defmodule WhenToProcess.RidesTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides

  # TODO: Cycle through implementations to make sure they all work according to the specification
  describe "accept_ride_request" do
    test "ride is created" do
      ride_request = insert(:ride_request)
      driver = insert(:driver)

      {:ok, %Rides.Ride{} = ride} = Rides.accept_ride_request(ride_request, driver)

      assert ride.ride_request_id == ride_request.id
      assert ride.driver_id == driver.id
    end

    test "cannot accept cancelled RideRequest" do
      ride_request = insert(:ride_request, cancelled_at: DateTime.utc_now())
      driver = insert(:driver)

      {:error, "This ride request cannot be accepted because it was cancelled"} = Rides.accept_ride_request(ride_request, driver)
    end

    test "cannot accept RideRequest with an associated ride" do
      ride_request = insert(:ride_request)
      driver1 = insert(:driver)

      {:ok, %Rides.Ride{} = ride} = Rides.accept_ride_request(ride_request, driver1)

      driver2 = insert(:driver)
      {:error, "This ride request cannot be accepted because it has already been accepted"} = Rides.accept_ride_request(ride_request, driver2)
    end
  end
end
