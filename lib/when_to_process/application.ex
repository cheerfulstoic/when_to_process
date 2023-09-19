defmodule WhenToProcess.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    IO.inspect(System.get("RIDES_GLOBAL_IMPLEMENTATION_MODULE"), label: :RIDES_GLOBAL_IMPLEMENTATION_MODULE)
    IO.inspect(System.get("RIDES_INDIVIDUAL_IMPLEMENTATION_MODULE"), label: :RIDES_INDIVIDUAL_IMPLEMENTATION_MODULE)

    children =
      [
        # Start the Telemetry supervisor
        WhenToProcessWeb.Telemetry,
        # WhenToProcess.ProcessTelemetry,
        # Start the Ecto repository
        WhenToProcess.Repo,
        # Start the PubSub system
        {Phoenix.PubSub, name: WhenToProcess.PubSub},
        # WhenToProcessWeb.Presence,
        # Start Finch
        {Finch, name: WhenToProcess.Finch},
        # Start the Endpoint (http/https)
        WhenToProcessWeb.Endpoint,
        WhenToProcess.PromEx
        # Start a worker by calling: WhenToProcess.Worker.start_link(arg)
        # {WhenToProcess.Worker, arg}
      ] ++ WhenToProcess.Rides.child_specs()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WhenToProcess.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WhenToProcessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
