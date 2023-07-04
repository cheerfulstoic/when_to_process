defmodule WhenToProcess.Rides.RideRequest do
  use Ecto.Schema
  import Ecto.Changeset

  alias WhenToProcess.Rides.Passenger
  alias WhenToProcess.Rides.Ride

  schema "ride_requests" do
    field :uuid, Ecto.UUID
    field :cancelled_at, :naive_datetime

    belongs_to :passenger, Passenger

    has_one :created_ride, Ride, foreign_key: :ride_request_id

    timestamps()
  end

  def changeset_for_insert(attrs) do
    attrs =
      attrs =
        attrs
        |> Map.put(:uuid, Ecto.UUID.generate())
        |> Map.put_new(:created_ride, nil)

    %__MODULE__{}
    |> changeset(Map.put(attrs, :uuid, Ecto.UUID.generate()))
  end

  @doc false
  def changeset(ride_request, attrs) do
    ride_request
    |> cast(attrs, [:uuid, :cancelled_at, :passenger_id])
    |> validate_required([:uuid])
    |> cast_assoc(:passenger)
    |> cast_assoc(:created_ride)
    |> unique_constraint(:passenger_id, name: :ride_requests_passenger_id_cancelled_at_uniq_index, error_key: :base, message: "Passenger cannot have multiple open ride requests")
  end

  def check_can_be_accepted(%{cancelled_at: value}) when not is_nil(value) do
    {:error, "This ride request cannot be accepted because it was cancelled"}
  end

  def check_can_be_accepted(ride_request) do
    EctoRequireAssociations.ensure!(ride_request, [:created_ride])

    case ride_request.created_ride do
      %Ride{} ->
        {:error, "This ride request cannot be accepted because it has already been accepted"}

      _ ->
        :ok
    end
  end

  def check_can_be_accepted(_ride_request), do: :ok
end
