defmodule WhenToProcess.RidesTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides

  setup context do
    # config :when_to_process, WhenToProcess.Rides, implementation: WhenToProcess.Rides.ProcessesWithETS
    old_value = Application.get_env(:when_to_process, WhenToProcess.Rides)
                # |> IO.inspect(label: :old_value)

    # IO.inspect(context[:rides_module], label: :"@rides_module")
    Application.put_env(:when_to_process, WhenToProcess.Rides, Keyword.put(old_value, :implementation, context[:rides_module]))
    context[:rides_module].reset()

    on_exit(fn ->
      Application.put_env(:when_to_process, WhenToProcess.Rides, old_value)
    end)

    []
  end

  # Test each module to make sure that they all work the same WRT the behavior API
  [
    Rides.DB,
    Rides.ProcessesOnly,
    Rides.ProcessesWithETS
  ]
  |> Enum.each(fn rides_module ->
    @rides_module rides_module

    # TODO: Cycle through implementations to make sure they all work according to the specification
    describe "#{rides_module}: available_drivers" do
      @describetag rides_module: rides_module

      test "driver is notified of request" do
        center_position = WhenToProcess.Locations.city_position(:stockholm)

        # Adjusting bearing along a cardinal direction because we test a box, not a circle
        bearing = WhenToProcess.Locations.bearing_for(:up)
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 1_990)
        {:ok, driver} =
          params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()

        driver_uuids = @rides_module.available_drivers(center_position, 3) |> Enum.map(& &1.uuid)

        assert driver_uuids == [driver.uuid]
      end

      test "we should only receive requests for the top three nearest drivers" do
        center_position = WhenToProcess.Locations.city_position(:stockholm)

        # Adjusting bearing along a cardinal direction because we test a box, not a circle
        bearing = WhenToProcess.Locations.bearing_for(:left)
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 11)
        {:ok, driver_11} =
          params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()
        bearing = WhenToProcess.Locations.bearing_for(:right)
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 10)
        {:ok, driver_10} =
          params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 20)
        {:ok, driver_20} =
          params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 30)
        {:ok, _driver_30} =
          params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()

        driver_uuids = @rides_module.available_drivers(center_position, 3) |> Enum.map(& &1.uuid)

        assert driver_uuids == [driver_10.uuid, driver_11.uuid, driver_20.uuid]
      end

      test "driver which isn't ready is not notified of request" do
        center_position = WhenToProcess.Locations.city_position(:stockholm)

        # Adjusting bearing along a cardinal direction because we test a box, not a circle
        bearing = WhenToProcess.Locations.bearing_for(:up)
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 1_990)
        {:ok, _driver} =
          params_for(:driver, ready_for_passengers: false, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()

        driver_uuids = @rides_module.available_drivers(center_position, 3) |> Enum.map(& &1.uuid)

        assert driver_uuids == []
      end

      test "driver which is too far away is not notified of request" do
        center_position = WhenToProcess.Locations.city_position(:stockholm)

        # Adjusting bearing along a cardinal direction because we test a box, not a circle
        bearing = WhenToProcess.Locations.bearing_for(:up)
        {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 2_010)
        {:ok, _driver} =
          params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
          |> Rides.create_driver()

        driver_uuids = @rides_module.available_drivers(center_position, 3) |> Enum.map(& &1.uuid)

        assert driver_uuids == []
      end
    end

#     describe "#{rides_module}: accept_ride_request" do
#       @describetag rides_module: rides_module

#       test "ride is created" do
#         ride_request = insert(:ride_request)
#         driver = insert(:driver, ready_for_passengers: true)

#         {:ok, %Rides.Ride{} = ride} = Rides.accept_ride_request(ride_request, driver)

#         assert ride.ride_request_id == ride_request.id
#         assert ride.driver_id == driver.id
#       end

#       test "cannot accept cancelled RideRequest" do
#         ride_request = insert(:ride_request, cancelled_at: DateTime.utc_now())
#         driver = insert(:driver)

#         {:error, "This ride request cannot be accepted because it was cancelled"} = Rides.accept_ride_request(ride_request, driver)
#       end

#       test "cannot accept RideRequest with an associated ride" do
#         ride_request = insert(:ride_request)
#         driver1 = insert(:driver)

#         {:ok, %Rides.Ride{} = ride} = Rides.accept_ride_request(ride_request, driver1)

#         driver2 = insert(:driver)
#         {:error, "This ride request cannot be accepted because it has already been accepted"} = Rides.accept_ride_request(ride_request, driver2)
#       end
#     end
  end)
end
