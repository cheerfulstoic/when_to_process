defmodule WhenToProcess.Rides.Passenger do
  use Ecto.Schema
  import Ecto.Changeset

  alias WhenToProcess.Rides.RideRequest

  schema "passengers" do
    field :name, :string

    field :latitude, :float
    field :longitude, :float

    # TODO: Rename to `current_ride_request`
    has_one :ride_request, RideRequest,
      where: [cancelled_at: nil]

    has_one :current_ride, through: [:ride_request, :ride]

    timestamps()
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
    |> cast(attrs, [:name, :latitude, :longitude])
    |> validate_required([:name, :latitude, :longitude])
    |> cast_assoc(:ride_request)
  end
end
