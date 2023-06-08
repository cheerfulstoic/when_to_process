defmodule WhenToProcess.Rides.ProcessesWithETS.Supervisor do
  use Supervisor

  alias WhenToProcess.Rides.ProcessesWithETS

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      ProcessesWithETS.DriverInformation,
      {Registry, keys: :unique, name: :driver_server_registry},
      {DynamicSupervisor, strategy: :one_for_one, name: :driver_dynamic_supervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
