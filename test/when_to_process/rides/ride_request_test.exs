defmodule WhenToProcess.Rides.RideRequestTest do
  use WhenToProcess.DataCase

  import WhenToProcess.Factory

  alias WhenToProcess.Rides.RideRequest

  describe ".check_can_be_accepted" do
    test "previously cancelled request" do
      ride_request = build(:ride_request, cancelled_at: DateTime.utc_now())

      assert {:error, "This ride request cannot be accepted because it was cancelled"} = RideRequest.check_can_be_accepted(ride_request)
    end

    test "can be accepted" do
      ride_request = build(:ride_request, cancelled_at: nil)

      assert :ok = RideRequest.check_can_be_accepted(ride_request)
    end
  end

  describe ".changeset" do
    test "already accepted" do
      passenger = insert(:passenger)
      insert(:ride_request, passenger: passenger)

      {:error, %Ecto.Changeset{errors: changeset_errors}} =
      result =
        %RideRequest{}
        |> RideRequest.changeset(%{passenger_id: passenger.id})
        |> WhenToProcess.Repo.insert()

      assert [base: {"Passenger cannot have multiple open ride requests", _}] = changeset_errors
    end
  end
end


