defmodule WhenToProcess.Locations do
  @type position :: {float(), float()}

  # Distances are in meters
  @cities %{
    stockholm: %{
      center: {59.3294, 18.0686},
      radius: 10_000
    }
  }
  @pi 3.14159

  @max_bearing 2.0 * @pi

  def bearing_for(:up), do: 0
  def bearing_for(:right), do: 0.5 * @pi
  def bearing_for(:down), do: 1.0 * @pi
  def bearing_for(:left), do: 1.5 * @pi
  def bearing_for(_), do: nil

  def random_bearing do
    :rand.uniform() * 2 * @pi
  end

  def standardize_bearing(bearing) do
    cond do
      bearing < 0 ->
        standardize_bearing(bearing + @max_bearing)

      bearing > @max_bearing ->
        standardize_bearing(bearing - @max_bearing)

      true ->
        bearing
    end
  end

  def city_position(city_label) do
    data = Map.get(@cities, city_label)

    data[:center]
  end

  def random_location(city_label) do
    data = Map.get(@cities, city_label)

    data[:center]
    |> adjust_randomly(data[:radius])
  end

  defp adjust_randomly(position, max_distance) do
    distance = :rand.uniform() * max_distance
    bearing = :rand.uniform() * 2 * @pi

    case Geocalc.destination_point(position, bearing, distance) do
      {:ok, [latitude, longitude]} ->
        {:ok, {latitude, longitude}}

      error ->
        error
    end
  end

  def adjust(position, bearing, distance) do
    case Geocalc.destination_point(position, bearing, distance) do
      {:ok, [latitude, longitude]} ->
        {:ok, {latitude, longitude}}

      error ->
        error
    end
  end
end
