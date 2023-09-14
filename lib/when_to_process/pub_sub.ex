defmodule WhenToProcess.PubSub do
  alias WhenToProcess.Rides

  require Logger

  def broadcast(topic, message) do
    # Logger.debug("BROADCAST: #{topic} | #{inspect(message)}")

    Phoenix.PubSub.broadcast(__MODULE__, topic, message)
  end

  def broadcast_record_create(record) do
    for topic <- ~w[records records:#{record_type(record)}] do
      broadcast(topic, {:record_created, record})
    end

    record
  end

  def broadcast_record_update(record) do
    for topic <-
          ~w[records records:#{record_type(record)} records:#{record_type(record)}:#{record.id}] do
      broadcast(topic, {:record_updated, record})
    end

    record
  end

  defp record_type(%Rides.Ride{}), do: "ride"
  defp record_type(%Rides.RideRequest{}), do: "ride_request"
  defp record_type(%Rides.Driver{}), do: "driver"
  defp record_type(%Rides.Passenger{}), do: "passenger"
end
