defmodule WhenToProcess.ProcessTelemetry do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def monitor(_pid, _module) do
    # Disabled Temporarily (?)
    # GenServer.cast(__MODULE__, {:monitor, pid, module})
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    {:ok, %{}}
  end

  @impl true
  def handle_cast({:monitor, pid, module}, modules_by_ref) do
    ref = Process.monitor(pid)
    # TODO: Send telemetry if `:DOWN` is returned here

    {:noreply, Map.put(modules_by_ref, ref, module)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, reason} = tuple, modules_by_ref) do
    if reason != {:shutdown, :peer_closed} do
      module = Map.get(modules_by_ref, ref)

      IO.inspect(module, label: :DOWN!)
      IO.inspect(tuple, label: :DOWN!)
    end

    if reason not in [:noproc] do
      module = Map.get(modules_by_ref, ref)

      :telemetry.execute(
        [:when_to_process, :process_crash],
        %{count: 1},
        %{module: module_to_statsd(module), reason: reason_to_statsd(reason)}
      )
    end

    {:noreply, Map.delete(modules_by_ref, ref)}
  end

  defp module_to_statsd(module) do
    module
    |> to_string()
    |> String.replace(".", "_")
  end

  defp reason_to_statsd(reason) when is_atom(reason) or is_binary(reason) do
    to_string(reason)
    |> String.slice(0..20)
  end

  defp reason_to_statsd(reason) when is_tuple(reason) do
    reason
    |> Tuple.to_list()
    |> Enum.join("_")
  end

  defp reason_to_statsd(reason) do
    inspect(reason)
  end
end
