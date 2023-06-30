defmodule Mix.Tasks.Drivers do
  @moduledoc "TODO"
  use Mix.Task

  @shortdoc "TODO"
  def run([count]) do
    count = String.to_integer(count)

    # To run `runtime.exs`
    Mix.Task.run("app.config")

    HTTPoison.start()
    # WhenToProcessWeb.Telemetry.start_link(nil)
    {:ok, _} = Application.ensure_all_started(:slipstream)

    ws_base = Application.get_env(:when_to_process, :client)[:ws_base]
              |> IO.inspect(label: :ws_base)

    IO.puts("socket stuff")
    0..count
    |> Enum.with_index()
    |> Enum.each(fn {_, index} ->
      {:ok, _driver_pid} = WhenToProcess.Client.Driver.start_link(%{
        slipstream_config: [
          uri: "#{ws_base}/socket/websocket",
          reconnect_after_msec: [200, 500, 1_000, 2_000],
          mint_opts: [
            log: true,
            protocols: [:http1],
            transport_opts: [inet6: true]
          ]
        ]
      })

      Process.sleep(20)
    end)

    IO.puts("socket stuff DONE")

    Process.sleep(100_000_000)
  end
end

