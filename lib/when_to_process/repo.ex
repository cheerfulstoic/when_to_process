defmodule WhenToProcess.Repo do
  use Ecto.Repo,
    otp_app: :when_to_process,
    adapter: Ecto.Adapters.Postgres
end
