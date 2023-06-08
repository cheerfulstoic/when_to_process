defmodule WhenToProcess.Rides.Driver do
  use Ecto.Schema
  import Ecto.Changeset

  alias WhenToProcess.Rides.Ride

  schema "drivers" do
    field :uuid, Ecto.UUID
    field :name, :string

    field :latitude, :float
    field :longitude, :float
    field :ready_for_passengers, :boolean, default: false

    has_one :current_ride, Ride, where: [dropped_off: nil]

    timestamps()
  end

  def changeset_for_insert(attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :uuid, Ecto.UUID.generate()))
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
    |> cast(attrs, [:uuid, :name, :latitude, :longitude, :ready_for_passengers])
    |> validate_required([:uuid, :name, :latitude, :longitude, :ready_for_passengers])
  end
end
