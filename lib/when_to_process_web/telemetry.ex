defmodule WhenToProcessWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 5_000},
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
      {TelemetryMetricsStatsd,
       System.get_env("TELEMETRY_METRICS_STATSD_OPTS")
       |> Base.decode64!()
       |> :erlang.binary_to_term()
       |> IO.inspect(label: :opts)
       |> Keyword.put(:metrics, metrics())}
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

      summary("vm.system_counts.process_count"),
      summary("vm.system_counts.atom_count"),
      summary("vm.system_counts.port_count"),

      # summary("when_to_process.statistics.run_queue"),
      # summary("when_to_process.statistics.run_queue_lengths"),
      summary("when_to_process.statistics.io_input"),
      summary("when_to_process.statistics.io_output"),
      summary("when_to_process.statistics.reductions_singe_last_call"),
      summary("when_to_process.statistics.total_active_tasks"),
      summary("when_to_process.statistics.total_active_tasks_all"),

      # Slipstream
      summary("slipstream.client.connect.stop.duration"),
      summary("slipstream.client.join.stop.duration"),
      summary("slipstream.client.handle_call.stop.duration"),
      summary("slipstream.client.handle_cast.stop.duration"),
      summary("slipstream.client.handle_info.stop.duration"),
      summary("slipstream.client.handle_leave.stop.duration"),
      summary("slipstream.client.handle_message.stop.duration"),
      summary("slipstream.client.handle_reply.stop.duration"),
      summary("slipstream.client.init.stop.duration"),

      # Custom
      summary("when_to_process.rides.genserver_call.stop.duration",
        tags: [:implementation_module, :record_module, :message_key],
        unit: {:native, :millisecond}
      ),

      counter("when_to_process.process_crash.module", tags: [:reason, :module]),
      last_value("when_to_process.drivers.total"),
      last_value("when_to_process.passengers.total"),
      last_value("when_to_process.processes.module.driver_channels.total"),
      last_value("when_to_process.processes.module.passenger_channels.total"),
      last_value("when_to_process.processes.module.RecordStore.total"),
      last_value("when_to_process.processes.module.PartitionedRecordStore.total"),
      last_value("when_to_process.processes.module.ETSPositionedRecordsStore.total"),
      last_value("when_to_process.processes.module.cowboy_clear.total"),
      last_value("when_to_process.processes.module.bandit_delegating_handler.total"),
      last_value("when_to_process.processes.module.processes_only_driver_server.total"),
      last_value(
        "when_to_process.processes.process_info.ets_positioned_records_store_for_driver.message_queue_len"
      ),
      last_value(
        "when_to_process.processes.process_info.ets_positioned_records_store_for_passenger.message_queue_len"
      ),
      last_value(
        "when_to_process.processes.process_info.positioned_record_store_for_driver.message_queue_len"
      ),
      last_value(
        "when_to_process.processes.process_info.positioned_record_store_for_passenger.message_queue_len"
      )
    ]
  end

  def module_to_key(module), do: String.replace(Macro.to_string(module), ".", "_")

  defp periodic_measurements do
    [
      {__MODULE__, :record_count, [WhenToProcess.Rides.Driver, :drivers]},
      {__MODULE__, :record_count, [WhenToProcess.Rides.Passenger, :passengers]},
      {__MODULE__, :measure_module_instance_counts,
        [[
          {WhenToProcessWeb.DriverChannel, :driver_channels},
          {WhenToProcessWeb.PassengerChannel, :passenger_channels},
          {WhenToProcess.Rides.RecordStore, :RecordStore},
          {WhenToProcess.Rides.ETSPositionedRecordsStore, :ETSPositionedRecordsStore},
          {WhenToProcess.Rides.PartitionedRecordStore, :PartitionedRecordStore},
          {:cowboy_clear, :cowboy_clear},
          {Bandit.DelegatingHandler, :bandit_delegating_handler},
        ]]
      },

      {__MODULE__, :process_info,
       [
         :"ets_positioned_records_store_for_Elixir.WhenToProcess.Rides.Driver",
         :ets_positioned_records_store_for_driver
       ]},
      {__MODULE__, :process_info,
       [
         :"ets_positioned_records_store_for_Elixir.WhenToProcess.Rides.Passenger",
         :ets_positioned_records_store_for_passenger
       ]},
      {__MODULE__, :process_info,
       [
         :"positioned_record_store_dynamic_supervisor_for_Elixir.WhenToProcess.Rides.Driver",
         :positioned_record_store_for_driver
       ]},
      {__MODULE__, :process_info,
       [
         :"positioned_record_store_dynamic_supervisor_for_Elixir.WhenToProcess.Rides.Passenger",
         :positioned_record_store_for_passenger
       ]},
      {__MODULE__, :statistics, []}
    ]
  end

  def record_count(module, telemetry_name) do
    if WhenToProcess.Rides.ready?() do
      :telemetry.execute(
        [:when_to_process, telemetry_name],
        %{total: WhenToProcess.Rides.count(module)},
        %{}
      )
    end
  end

  def measure_module_instance_counts(specs) do
    module_counts =
      Process.list()
      |> Enum.frequencies_by(fn pid ->
        pid
        |> Process.info()
        |> get_in([:dictionary, :"$initial_call"])
        |> case do
          {found_mod, _, _} -> found_mod
          {found_mod, _} -> found_mod
          _other -> nil
        end
      end)

    Enum.each(specs, fn
      {module, telemetry_name} ->
        :telemetry.execute(
          [:when_to_process, :processes, :module, telemetry_name],
          %{total: Map.get(module_counts, module, 0)},
          %{}
        )
    end)

  end

  def measure_module_instance_count(module), do: measure_module_instance_count(module, module)

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
            _other -> nil
          end

        found_mod == module
      end)

    # IO.inspect(total, label: telemetry_name)
    :telemetry.execute(
      [:when_to_process, :processes, :module, telemetry_name],
      %{total: total},
      %{}
    )
  end

  def process_info(process_name, telemetry_name) do
    Process.whereis(process_name)
    |> case do
      nil ->
        # Should only happen on startup
        nil

      pid ->
        pid
        |> Process.info(:message_queue_len)
        |> case do
          {:message_queue_len, length} ->
            :telemetry.execute(
              [:when_to_process, :processes, :process_info, telemetry_name],
              %{message_queue_len: length},
              %{}
            )
        end
    end
  end

  def statistics do
    {{:input, io_input}, {:output, io_output}} = :erlang.statistics(:io)
    {_, reductions_since_last_call} = :erlang.statistics(:reductions)

    :telemetry.execute(
      [:when_to_process, :statistics],
      %{
        # run_queue: :erlang.statistics(:run_queue),
        # run_queue_lengths: :erlang.statistics(:run_queue_lengths),
        io_input: io_input,
        io_output: io_output,
        reductions_since_last_call: reductions_since_last_call,
        total_active_tasks: :erlang.statistics(:total_active_tasks),
        total_active_tasks_all: :erlang.statistics(:total_active_tasks_all)
      },
      %{}
    )
  end
end
