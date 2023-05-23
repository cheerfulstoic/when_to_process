defmodule WhenToProcess.Rides.DriverTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides.Driver

  describe ".changeset" do
    test "position" do
      driver =
        %Driver{}
        |> Driver.changeset(%{position: {1.23, 3.21}})
        |> Ecto.Changeset.apply_changes()

      assert driver.latitude == 1.23
      assert driver.longitude == 3.21
    end

    test "bad position" do
      driver =
        %Driver{}
        |> Driver.changeset(%{position: 1.23})
        |> Ecto.Changeset.apply_changes()

      assert driver.latitude == nil
      assert driver.longitude == nil
    end
  end

  describe ".current_ride" do
    test "Returns the ride which isn't dropped_off" do
      driver = insert(:driver)
      # insert ride both before and after to gain some confidence that
      # we're not just returning the first or last ride to be inserted
      insert(:ride, dropped_off: DateTime.utc_now(), driver: driver)
      current_ride = insert(:ride, dropped_off: nil, driver: driver)
      insert(:ride, dropped_off: DateTime.utc_now(), driver: driver)

      driver = WhenToProcess.Repo.preload(driver, :current_ride)
      assert driver.current_ride.id == current_ride.id
    end
  end
end
