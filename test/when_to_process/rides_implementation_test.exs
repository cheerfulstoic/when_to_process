defmodule WhenToProcess.RidesImplementationTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides

  setup _context do
    Rides.reset()

    []
  end

  # Tests should be run multiple times using different values of RIDES_IMPLEMENTATION_MODULE

  def create_driver(attrs \\ []) do
    Rides.create(Rides.Driver, params_for(:driver, attrs))
  end

  describe "list_nearby" do
    test "driver is notified of request" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:up)

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 1_990)

      {:ok, driver} =
        params_for(:driver,
          ready_for_passengers: true,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      ready_fn = & &1.ready_for_passengers

      driver_uuids =
        Rides._global_state_implementation_module().list_nearby(
          Rides.Driver,
          center_position,
          2_000,
          ready_fn,
          3
        )
        |> Enum.map(& &1.uuid)

      assert driver_uuids == [driver.uuid]
    end

    test "we should only receive requests for the top three nearest drivers" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:left)

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 11)

      {:ok, driver_11} =
        params_for(:driver,
          ready_for_passengers: true,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      bearing = WhenToProcess.Locations.bearing_for(:right)

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 10)

      {:ok, driver_10} =
        params_for(:driver,
          ready_for_passengers: true,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 20)

      {:ok, driver_20} =
        params_for(:driver,
          ready_for_passengers: true,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 30)

      {:ok, _driver_30} =
        params_for(:driver,
          ready_for_passengers: true,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      ready_fn = & &1.ready_for_passengers

      driver_uuids =
        Rides._global_state_implementation_module().list_nearby(
          Rides.Driver,
          center_position,
          2_000,
          ready_fn,
          3
        )
        |> Enum.map(& &1.uuid)

      assert driver_uuids == [driver_10.uuid, driver_11.uuid, driver_20.uuid]
    end

    test "driver which isn't ready is not notified of request" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:up)

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 1_990)

      {:ok, _driver} =
        params_for(:driver,
          ready_for_passengers: false,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      ready_fn = & &1.ready_for_passengers

      driver_uuids =
        Rides._global_state_implementation_module().list_nearby(
          Rides.Driver,
          center_position,
          2_000,
          ready_fn,
          3
        )
        |> Enum.map(& &1.uuid)

      assert driver_uuids == []
    end

    test "driver which is too far away is not notified of request" do
      center_position = WhenToProcess.Locations.city_position(:stockholm)

      # Adjusting bearing along a cardinal direction because we test a box, not a circle
      bearing = WhenToProcess.Locations.bearing_for(:up)

      {:ok, {driver_latitude, driver_longitude}} =
        WhenToProcess.Locations.adjust(center_position, bearing, 2_010)

      {:ok, _driver} =
        params_for(:driver,
          ready_for_passengers: true,
          latitude: driver_latitude,
          longitude: driver_longitude
        )
        |> create_driver()

      ready_fn = & &1.ready_for_passengers

      driver_uuids =
        Rides._global_state_implementation_module().list_nearby(
          Rides.Driver,
          center_position,
          2_000,
          ready_fn,
          3
        )
        |> Enum.map(& &1.uuid)

      assert driver_uuids == []
    end
  end
end
