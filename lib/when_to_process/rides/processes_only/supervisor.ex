defmodule WhenToProcess.Rides.ProcessesOnly.Supervisor do
  use Supervisor

  alias WhenToProcess.Rides.ProcessesOnly

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      ProcessesOnly.DriverInformation,
      {Registry, keys: :unique, name: :driver_server_registry},
      {DynamicSupervisor, strategy: :one_for_one, name: :driver_dynamic_supervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
