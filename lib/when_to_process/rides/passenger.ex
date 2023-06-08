defmodule WhenToProcess.Rides.Passenger do
  use Ecto.Schema
  import Ecto.Changeset

  alias WhenToProcess.Rides.RideRequest

  schema "passengers" do
    field :uuid, Ecto.UUID
    field :name, :string

    field :latitude, :float
    field :longitude, :float

    # TODO: Rename to `current_ride_request`
    has_one :ride_request, RideRequest,
      where: [cancelled_at: nil]

    has_one :current_ride, through: [:ride_request, :created_ride]

    timestamps()
  end

  def changeset_for_insert(attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :uuid, Ecto.UUID.generate()))
  end

  @doc false
  def changeset(passenger, attrs) do
    attrs =
      with %{position: {latitude, longitude}} <- attrs do
        attrs
        |> Map.put(:latitude, latitude)
        |> Map.put(:longitude, longitude)
      end

    passenger
    |> cast(attrs, [:uuid, :name, :latitude, :longitude])
    |> validate_required([:uuid, :name, :latitude, :longitude])
    |> cast_assoc(:ride_request)
  end
end
