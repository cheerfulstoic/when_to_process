defmodule WhenToProcess.Repo.Migrations.CreateRideRequests do
  use Ecto.Migration

  def change do
    create table(:ride_requests) do
      add :uuid, :uuid, null: false

      add :passenger_id, references(:passengers), null: false

      add :cancelled_at, :naive_datetime, null: true

      timestamps()
    end

    create(unique_index(:ride_requests, :passenger_id, where: "cancelled_at IS NULL", name: :ride_requests_passenger_id_cancelled_at_uniq_index))

    execute(
      "CREATE TYPE ride_request_pings_response AS ENUM ('accepted', 'rejected')",
      "DROP TYPE ride_request_pings_response"
    )

    create table(:ride_request_pings) do
      add :ride_request_id, references(:ride_requests), null: false
      add :driver_id, references(:passengers), null: false

      add :response, :ride_request_pings_response, null: true

      timestamps()
    end

    create(unique_index(:ride_request_pings, [:ride_request_id, :driver_id]))

    create table(:rides) do
      add :driver_id, references(:drivers), null: false

      add :picked_up, :naive_datetime, null: true
      add :dropped_off, :naive_datetime, null: true

      add :ride_request_id, references(:ride_requests), null: false

      timestamps()
    end

    create(unique_index(:rides, :ride_request_id))
    create(unique_index(:rides, :driver_id, where: "dropped_off IS NULL"))
  end
end
