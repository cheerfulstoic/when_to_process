defmodule WhenToProcess.RidesTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides

  setup _context do
    Rides.reset()

    []
  end

  # Tests should be run multiple times using different values of RIDES_IMPLEMENTATION_MODULE

  describe "list" do
    test "No drivers" do
      assert Rides.list(Rides.Driver) == []
    end

    test "A driver" do
      {:ok, %{uuid: uuid}} = Rides.create(Rides.Driver, params_with_assocs(:driver))

      assert [%{uuid: ^uuid}] = Rides.list(Rides.Driver)
    end

    test "Two drivers" do
      {:ok, driver1} = Rides.create(Rides.Driver, params_with_assocs(:driver))
      {:ok, driver2} = Rides.create(Rides.Driver, params_with_assocs(:driver))

      assert_lists_equal(
        Rides.list(Rides.Driver),
        [driver1, driver2],
        &assert_structs_equal(&1, &2, [:uuid])
      )
    end

    test "Many drivers" do
      drivers =
        Enum.map(0..10, fn _ ->
          {:ok, driver} = Rides.create(Rides.Driver, params_with_assocs(:driver))

          driver
        end)

      assert_lists_equal(
        Rides.list(Rides.Driver),
        drivers,
        &assert_structs_equal(&1, &2, [:uuid])
      )
    end
  end

  describe "count" do
    test "No drivers" do
      assert Rides.count(Rides.Driver) == 0
    end

    test "A driver" do
      Rides.create(Rides.Driver, params_with_assocs(:driver))

      assert Rides.count(Rides.Driver) == 1
    end

    test "Two drivers" do
      Rides.create(Rides.Driver, params_with_assocs(:driver))
      Rides.create(Rides.Driver, params_with_assocs(:driver))

      assert Rides.count(Rides.Driver) == 2
    end

    test "Many drivers" do
      Enum.map(0..10, fn _ -> Rides.create(Rides.Driver, params_with_assocs(:driver)) end)

      assert Rides.count(Rides.Driver) == 11
    end
  end

  describe "get" do
    test "Driver" do
      {:ok, driver} = Rides.create(Rides.Driver, params_with_assocs(:driver))
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
      {:ok, driver} = Rides.create(Rides.Driver, params_with_assocs(:driver))
      assert Rides.get!(Rides.Driver, driver.uuid) == driver

      non_existant_uuid = Ecto.UUID.generate()

      assert_raise RuntimeError,
                   "Could not found Elixir.WhenToProcess.Rides.Driver `#{non_existant_uuid}`",
                   fn ->
                     Rides.get!(Rides.Driver, non_existant_uuid) == nil
                   end
    end

    test "No drivers" do
      non_existant_uuid = Ecto.UUID.generate()

      assert_raise RuntimeError,
                   "Could not found Elixir.WhenToProcess.Rides.Driver `#{non_existant_uuid}`",
                   fn ->
                     Rides.get!(Rides.Driver, non_existant_uuid) == nil
                   end
    end
  end

  describe "set_position" do
    test "Can change latitude and longitude" do
      {:ok, driver} =
        Rides.create(Rides.Driver, params_with_assocs(:driver, latitude: 1.23, longitude: -3.21))

      {:ok, updated_driver} = Rides.set_position(driver, {-3.21, 1.23})

      assert updated_driver.latitude == -3.21
      assert updated_driver.longitude == 1.23

      fresh_driver = Rides.get!(Rides.Driver, driver.uuid)

      assert fresh_driver.latitude == -3.21
      assert fresh_driver.longitude == 1.23
    end

    test "Value isn't changed, is OK" do
      {:ok, driver} =
        Rides.create(Rides.Driver, params_with_assocs(:driver, latitude: 1.23, longitude: -3.21))

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
      {:ok, driver} =
        Rides.create(Rides.Driver, params_with_assocs(:driver, latitude: 1.23, longitude: -3.21))

      {:ok, _updated_driver} = Rides.set_position(driver, {-3.21, 1.23})

      driver = Rides.reload(driver)

      assert driver.latitude == -3.21
      assert driver.longitude == 1.23
    end
  end

  describe "accept_ride_request" do
    test "ride is created" do
      {:ok, ride_request} = Rides.create(Rides.RideRequest, params_with_assocs(:ride_request))

      {:ok, driver} =
        Rides.create(Rides.Driver, params_with_assocs(:driver, ready_for_passengers: true))

      {:ok, %Rides.RideRequest{created_ride: created_ride}} =
        Rides.accept_ride_request(ride_request, driver)

      assert created_ride.driver_id == driver.id
    end

    test "cannot accept cancelled RideRequest" do
      {:ok, ride_request} =
        Rides.create(
          Rides.RideRequest,
          params_with_assocs(:ride_request, cancelled_at: DateTime.utc_now())
        )

      {:ok, driver} = Rides.create(Rides.Driver, params_with_assocs(:driver))

      {:error, "This ride request cannot be accepted because it was cancelled"} =
        Rides.accept_ride_request(ride_request, driver)
    end

    test "cannot accept RideRequest with an associated ride" do
      {:ok, ride_request} = Rides.create(Rides.RideRequest, params_with_assocs(:ride_request))
      {:ok, driver1} = Rides.create(Rides.Driver, params_with_assocs(:driver))

      {:ok, ride_request} = Rides.accept_ride_request(ride_request, driver1)

      {:ok, driver2} = Rides.create(Rides.Driver, params_with_assocs(:driver))

      {:error, "This ride request cannot be accepted because it has already been accepted"} =
        Rides.accept_ride_request(ride_request, driver2)
    end
  end

  describe "cancel_request" do
    test "request is cancelled" do
      {:ok, ride_request} =
        Rides.create(
          Rides.RideRequest,
          params_with_assocs(:ride_request, cancelled_at: DateTime.utc_now())
        )

      {:ok, ride_request} = Rides.cancel_request(ride_request)

      ride_request = Rides.reload(ride_request)

      assert ride_request.cancelled_at != nil
    end

    test "request has already been accepted" do
      # TODO
    end

    test "request is already cancelled" do
      {:ok, ride_request} =
        Rides.create(
          Rides.RideRequest,
          params_with_assocs(:ride_request, cancelled_at: DateTime.utc_now())
        )

      # TODO
    end
  end
end
