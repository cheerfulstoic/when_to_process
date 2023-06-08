defmodule WhenToProcess.Rides.Ride do
  use Ecto.Schema
  import Ecto.Changeset

  alias WhenToProcess.Rides.Driver
  alias WhenToProcess.Rides.RideRequest

  schema "rides" do
    field :dropped_off, :naive_datetime

    belongs_to :driver, Driver

    belongs_to :ride_request, RideRequest

    timestamps()
  end

  def changeset_for_insert(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @doc false
  def changeset(ride, attrs) do
    ride
    |> cast(attrs, [:driver_id, :ride_request_id])
    |> cast_assoc(:driver)
    |> cast_assoc(:ride_request)
    |> unique_constraint(:ride_request_id, error_key: :base, message: "This ride request cannot be accepted because it has already been accepted")
  end
end

