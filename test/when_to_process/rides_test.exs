defmodule WhenToProcess.RidesTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides

  setup context do
    Rides.reset()

    []
  end

  # Tests should be run multiple times using different values of RIDES_IMPLEMENTATION_MODULE

  def create_driver(attrs \\ []) do
    Rides.create(Rides.Driver, params_for(:driver, attrs))
  end

  describe "list" do
    test "No drivers" do
      assert Rides.list(Rides.Driver) == []
    end

    test "A driver" do
      {:ok, %{uuid: uuid}} = create_driver()

      assert [%{uuid: ^uuid}] = Rides.list(Rides.Driver)
    end

    test "Two drivers" do
      {:ok, driver1} = create_driver()
      {:ok, driver2} = create_driver()

      assert_lists_equal(Rides.list(Rides.Driver), [driver1, driver2], &assert_structs_equal(&1, &2, [:uuid]))
    end

    test "Many drivers" do
      drivers =
        Enum.map(0..10, fn _ ->
          {:ok, driver} = create_driver()

          driver
        end)

      assert_lists_equal(Rides.list(Rides.Driver), drivers, &assert_structs_equal(&1, &2, [:uuid]))
    end
  end

  describe "count" do
    test "No drivers" do
      assert Rides.count(Rides.Driver) == 0
    end

    test "A driver" do
      create_driver()

      assert Rides.count(Rides.Driver) == 1
    end

    test "Two drivers" do
      create_driver()
      create_driver()

      assert Rides.count(Rides.Driver) == 2
    end

    test "Many drivers" do
      Enum.map(0..10, fn _ -> create_driver() end)

      assert Rides.count(Rides.Driver) == 11
    end
  end

  describe "get" do
    test "Driver" do
      {:ok, driver} = create_driver()
      assert Rides.get(Rides.Driver, driver.uuid) == driver

      non_existant_uuid = Ecto.UUID.generate()
      assert Rides.get(Rides.Driver, non_existant_uuid) == nil
    end

    test "No drivers" do
      non_existant_uuid = Ecto.UUID.generate()
      assert Rides.get(Rides.Driver, non_existant_uuid) == nil
    end
  end

  describe "get!" do
    test "Driver" do
      {:ok, driver} = create_driver()
      assert Rides.get!(Rides.Driver, driver.uuid) == driver

      non_existant_uuid = Ecto.UUID.generate()
      assert_raise RuntimeError, "Could not found Elixir.WhenToProcess.Rides.Driver `#{non_existant_uuid}`", fn ->
        Rides.get!(Rides.Driver, non_existant_uuid) == nil
      end
    end

    test "No drivers" do
      non_existant_uuid = Ecto.UUID.generate()
      assert_raise RuntimeError, "Could not found Elixir.WhenToProcess.Rides.Driver `#{non_existant_uuid}`", fn ->
        Rides.get!(Rides.Driver, non_existant_uuid) == nil
      end
    end
  end

  describe "set_position" do
    test "Can change latitude and longitude" do
      {:ok, driver} = create_driver(latitude: 1.23, longitude: -3.21)

      {:ok, updated_driver} = Rides.set_position(driver, {-3.21, 1.23})

      assert updated_driver.latitude == -3.21
      assert updated_driver.longitude == 1.23

      fresh_driver = Rides.get!(Rides.Driver, driver.uuid)

      assert fresh_driver.latitude == -3.21
      assert fresh_driver.longitude == 1.23
    end

    test "Value isn't changed, is OK" do
      {:ok, driver} = create_driver(latitude: 1.23, longitude: -3.21)

      {:ok, updated_driver} = Rides.set_position(driver, {1.23, -3.21})

      assert updated_driver.latitude == 1.23
      assert updated_driver.longitude == -3.21

      fresh_driver = Rides.get!(Rides.Driver, driver.uuid)

      assert fresh_driver.latitude == 1.23
      assert fresh_driver.longitude == -3.21
    end
  end

  describe "reload" do
    test "Driver" do
      {:ok, driver} = create_driver(latitude: 1.23, longitude: -3.21)

      {:ok, updated_driver} = Rides.set_position(driver, {-3.21, 1.23})

      driver = Rides.reload(driver)

      assert driver.latitude == -3.21
      assert driver.longitude == 1.23
    end
  end

  describe "list_nearby" do
    test "driver is notified of request" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:up)
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 1_990)
      {:ok, driver} =
        params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()

      ready_fn = (& &1.ready_for_passengers)
      driver_uuids = Rides._global_state_implementation_module().list_nearby(Rides.Driver, center_position, 2_000, ready_fn, 3) |> Enum.map(& &1.uuid)

      assert driver_uuids == [driver.uuid]
    end

    test "we should only receive requests for the top three nearest drivers" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:left)
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 11)
      {:ok, driver_11} =
        params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()
      bearing = WhenToProcess.Locations.bearing_for(:right)
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 10)
      {:ok, driver_10} =
        params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 20)
      {:ok, driver_20} =
        params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 30)
      {:ok, _driver_30} =
        params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()

      ready_fn = (& &1.ready_for_passengers)
      driver_uuids = Rides._global_state_implementation_module().list_nearby(Rides.Driver, center_position, 2_000, ready_fn, 3) |> Enum.map(& &1.uuid)

      assert driver_uuids == [driver_10.uuid, driver_11.uuid, driver_20.uuid]
    end

    test "driver which isn't ready is not notified of request" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:up)
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 1_990)
      {:ok, _driver} =
        params_for(:driver, ready_for_passengers: false, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()

      ready_fn = (& &1.ready_for_passengers)
      driver_uuids = Rides._global_state_implementation_module().list_nearby(Rides.Driver, center_position, 2_000, ready_fn, 3) |> Enum.map(& &1.uuid)

      assert driver_uuids == []
    end

    test "driver which is too far away is not notified of request" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:up)
      {:ok, {driver_latitude, driver_longitude}} = WhenToProcess.Locations.adjust(center_position, bearing, 2_010)
      {:ok, _driver} =
        params_for(:driver, ready_for_passengers: true, latitude: driver_latitude, longitude: driver_longitude)
        |> create_driver()

      ready_fn = (& &1.ready_for_passengers)
      driver_uuids = Rides._global_state_implementation_module().list_nearby(Rides.Driver, center_position, 2_000, ready_fn, 3) |> Enum.map(& &1.uuid)

      assert driver_uuids == []
    end
  end

#     describe "accept_ride_request" do
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
end
