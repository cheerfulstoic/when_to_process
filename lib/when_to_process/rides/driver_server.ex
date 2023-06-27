defmodule WhenToProcess.Rides.DriverServer do
  use GenServer

  @supervisor_name :driver_dynamic_supervisor
  def create(driver) do
    DynamicSupervisor.start_child(
      @supervisor_name,
      {__MODULE__, driver}
    )
  end

  def reset do
    DynamicSupervisor.which_children(@supervisor_name)
    |> Enum.each(fn {_, pid, :worker, [__MODULE__]} ->
      DynamicSupervisor.terminate_child(@supervisor_name, pid)
    end)
  end

  def update_driver(driver) do
    case Registry.lookup(:driver_server_registry, registry_key(driver.uuid)) do
      [{pid, _}] ->
        {:ok, GenServer.call(pid, {:update_driver, driver})}

      _ -> {:error, "Driver not found"}
    end
  end

  def start_link(driver) do
    GenServer.start_link(__MODULE__, driver, name: process_name(driver.uuid))
  end

  def get_driver(driver_uuid) do
    case Registry.lookup(:driver_server_registry, registry_key(driver_uuid)) do
      [{pid, _}] -> GenServer.call(pid, :get_driver)

      _ -> nil
    end
  end

  defp process_name(driver_uuid) do
    {:via, Registry, {:driver_server_registry, registry_key(driver_uuid)}}
  end

  defp registry_key(driver_uuid) do
    "driver:#{driver_uuid}"
  end

  # Callbacks

  @impl true
  def init(driver) do
    WhenToProcess.ProcessTelemetry.monitor(self(), __MODULE__)

    {:ok, driver}
  end

  @impl true
  def handle_call(:get_driver, _from, driver) do
    {:reply, driver, driver}
  end

  @impl true
  def handle_call({:update_driver, updated_driver}, _from, _old_driver) do
    {:reply, updated_driver, updated_driver}
  end
end


