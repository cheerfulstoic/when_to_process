defmodule WhenToProcess.Rides.Driver do
  use Ecto.Schema
  import Ecto.Changeset

  alias WhenToProcess.Rides.Ride

  schema "drivers" do
    field :name, :string

    field :latitude, :float
    field :longitude, :float
    field :ready_for_passengers, :boolean, default: false

    has_one :current_ride, Ride, where: [dropped_off: nil]

    timestamps()
  end

  @doc false
  def changeset(driver, attrs) do
    attrs =
      with %{position: {latitude, longitude}} <- attrs do
        attrs
        |> Map.put(:latitude, latitude)
        |> Map.put(:longitude, longitude)
        |> Map.delete(:position)
      end

    driver
    |> cast(attrs, [:name, :latitude, :longitude, :ready_for_passengers])
    |> validate_required([:name, :latitude, :longitude, :ready_for_passengers])
  end
end
