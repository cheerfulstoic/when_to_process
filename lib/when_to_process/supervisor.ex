defmodule WhenToProcess.Supervisor do
  @moduledoc "Helpers for supervisors"

  def ready?(pid_or_name) do
    if Process.whereis(pid_or_name) do
      %{active: active, specs: specs} =
        Supervisor.count_children(pid_or_name)

      active == specs
    end
  end
end
