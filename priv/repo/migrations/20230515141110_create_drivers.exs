defmodule WhenToProcess.Repo.Migrations.CreateDrivers do
  use Ecto.Migration

  def change do
    create table(:drivers) do
      add :name, :string, null: false
      add :latitude, :float
      add :longitude, :float
      add :ready_for_passengers, :boolean, default: false, null: false

      timestamps()
    end
  end
end
