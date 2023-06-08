defmodule WhenToProcess.Repo.Migrations.CreatePassengers do
  use Ecto.Migration

  def change do
    create table(:passengers) do
      add :uuid, :uuid, null: false

      add :name, :string, null: false

      add :latitude, :float
      add :longitude, :float

      timestamps()
    end
  end
end
