defmodule Mix.Tasks.DriversLoadTest do
  @moduledoc "TODO"
  use Mix.Task

  @shortdoc "TODO"
  def run([]) do
    run(["1.0"])
  end

  def run([scale]) do
    scale = String.to_float(scale)

    # To run `runtime.exs`
    Mix.Task.run("app.config")

    HTTPoison.start()
    # WhenToProcessWeb.Telemetry.start_link(nil)
    {:ok, _} = Application.ensure_all_started(:slipstream)

    ws_base = Application.get_env(:when_to_process, :client)[:ws_base]

    IO.puts("socket stuff")

    0..50_000
    |> Enum.with_index()
    |> Enum.each(fn {_, index} ->
      {:ok, _driver_pid} =
        WhenToProcess.Client.Driver.start_link(%{
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

      if rem(index, pause_interval(index, scale)) == 0 do
        IO.puts("PAUSE")
        Process.sleep(1_000)
      end
    end)

    IO.puts("socket stuff DONE")

    Process.sleep(100_000_000)
  end

  def pause_interval(index, scale) do
    round(pause_interval_base(index) * scale)
  end

  def pause_interval_base(index) when index < 1_000, do: 10
  def pause_interval_base(index) when index < 2_000, do: 8
  def pause_interval_base(index) when index < 3_000, do: 5
  def pause_interval_base(index) when index < 5_000, do: 3
  def pause_interval_base(index) when index < 100_000, do: 1
end
