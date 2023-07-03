defmodule WhenToProcess.Rides.DB do
  import Ecto.Query

  alias WhenToProcess.Repo
  alias WhenToProcess.Rides

  @behaviour Rides.State
  @behaviour Rides.GlobalState

  @impl Rides.State
  def state_child_spec(_record_module), do: nil

  @impl Rides.State
  def ready?(_record_module) do
    WhenToProcess.Repo in Ecto.Repo.all_running()
  end

  @impl Rides.GlobalState
  def list(record_module), do: Repo.all(record_module)

  @impl Rides.GlobalState
  def count(record_module) do
    Repo.aggregate(record_module, :count)
  end

  @impl Rides.State
  def get(record_module, uuid), do: Repo.get_by(record_module, uuid: uuid)

  @impl Rides.State
  def reload(record), do: Repo.reload(record)

  @impl Rides.State
  def reset(_record_module) do
    :ok
  end

  @impl Rides.GlobalState
  def list_nearby(record_module, position, distance, filter_fn, count) do
    [
      [latitude_west, longitude_south],
      [latitude_east, longitude_north]
    ] = Geocalc.bounding_box(position, distance)

    {latitude, longitude} = position

    from(
      driver in record_module,
      where: fragment("? BETWEEN ? AND ?", driver.latitude, ^latitude_west, ^latitude_east),
      where: fragment("? BETWEEN ? AND ?", driver.longitude, ^longitude_south, ^longitude_north),
      order_by: fragment("pow(? - ?, 2) + pow(? - ?, 2)", ^latitude, driver.latitude, ^longitude, driver.longitude),
      limit: ^count
    )
    |> Repo.all()
    |> Enum.filter(filter_fn)
  end

  @impl Rides.State
  def insert_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.insert(changeset) do
      WhenToProcess.PubSub.broadcast_record_create(record)

      {:ok, record}
    end
  end

  @impl Rides.State
  def update_changeset(%Ecto.Changeset{} = changeset) do
    with {:ok, record} <- Repo.update(changeset) do
      WhenToProcess.PubSub.broadcast_record_update(record)

      {:ok, record}
    end
  end
end
