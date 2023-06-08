defmodule WhenToProcessWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
      {TelemetryMetricsStatsd, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_join.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("when_to_process.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("when_to_process.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("when_to_process.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("when_to_process.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("when_to_process.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Custom
      summary("when_to_process.rides.processes_only.driver_information.start.duration",
        tags: [:message_key],
        unit: {:native, :millisecond}
      ),

      summary("when_to_process.rides.processes_only.driver_information.stop.duration",
        tags: [:message_key],
        unit: {:native, :millisecond}
      ),

      counter("when_to_process.process_crash.module", tags: [:reason, :module]),

      last_value("when_to_process.drivers.total"),
      last_value("when_to_process.processes.module.channels.total"),
      last_value("when_to_process.processes.module.processes_only_driver_server.total")
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :driver_count, []},
      {__MODULE__, :measure_module_instance_count, [Phoenix.Channel.Server, :channels]},
      {__MODULE__, :measure_module_instance_count, [WhenToProcess.Rides.DriverServer, :driver_server]}
    ]
  end

  def driver_count do
    if WhenToProcess.Rides.ready?() do
      :telemetry.execute([:when_to_process, :drivers], %{total: WhenToProcess.Rides.count_drivers()}, %{})
    end
  end

  def measure_module_instance_count(module, telemetry_name) do
    total =
      Process.list()
      |> Enum.count(fn pid ->
        found_mod =
          pid
          |> Process.info()
          |> get_in([:dictionary, :"$initial_call"])
          |> case do
            {found_mod, _, _} -> found_mod
            {found_mod, _} -> found_mod
            other -> nil
          end

        found_mod == module
      end)

    :telemetry.execute([:when_to_process, :processes, :module, telemetry_name], %{total: total}, %{})
  end

end
