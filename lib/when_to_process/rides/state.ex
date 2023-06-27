defmodule WhenToProcess.Rides.State do
  @callback state_child_spec(module()) :: Supervisor.child_spec() | nil
  @callback ready?(module()) :: boolean()
  @callback reset(module()) :: :ok
  @callback insert_changeset(Ecto.Changeset.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @callback update_changeset(Ecto.Changeset.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
end


