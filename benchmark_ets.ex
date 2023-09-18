Mix.install([
  {:benchee, "~> 1.1.0"}
])

defmodule Driver do
  defstruct [:uuid, :name, :latitude, :longitude, :read_for_passengers, :current_ride, :inserted_at, :updated_at]
end

defmodule ETSAgent do

  def start_link(name, options) do
    Agent.start_link fn ->
      :ets.new(name, options)
    end
  end
end

defmodule Position do
  def random_lat_long do
    {
      (:rand.uniform() * 180) - 90,
      (:rand.uniform() * 360) - 180,
    }
  end
end

{:ok, public_ets_agent_pid} = ETSAgent.start_link(:public_ets_agent, [:set, :public, :named_table])
{:ok, protected_ets_agent_pid} = ETSAgent.start_link(:protected_ets_agent, [:set, :protected, :named_table])


defmodule Test do
  def new_record do
    {latitude, longitude} = Position.random_lat_long()
    uuid = "BA75FB20-F0AF-46DC-83A1-EE049B3D357F"
    %Driver{
      uuid: uuid,
      name: "Dooah Leepah",
      latitude: latitude,
      longitude: longitude,
    }
  end

  def update_values(record, latitude, longitude) do
    [
      {2, latitude},
      {3, longitude},
      {4,
        record
        |> Map.put(:latitude, latitude)
        |> Map.put(:longitude, longitude)
      }
    ]
  end
end

record1 = Test.new_record()
# record2 = Test.new_record()
# record3 = Test.new_record()

Benchee.run(
  %{
    "public_ets_agent - update externally" => fn ->
      {latitude, longitude} = Position.random_lat_long()

      update_values = Test.update_values(record1, latitude, longitude)

      :ets.update_element(:public_ets_agent, record1.uuid, update_values)

    end,
    "public_ets_agent - update in agent" => fn ->
      {latitude, longitude} = Position.random_lat_long()

      update_values = Test.update_values(record1, latitude, longitude)

      Agent.update(public_ets_agent_pid, fn _reference ->
        :ets.update_element(:public_ets_agent, record1.uuid, update_values)
      end)
    end,
    "protected_ets_agent - update in agent" => fn ->
      {latitude, longitude} = Position.random_lat_long()

      update_values = Test.update_values(record1, latitude, longitude)

      Agent.update(protected_ets_agent_pid, fn _reference ->
        :ets.update_element(:protected_ets_agent, record1.uuid, update_values)
      end)
    end,


#     "public_ets_agent - update externally - batched" => fn ->
#       {latitude, longitude} = Position.random_lat_long()
#       update_values = Test.update_values(record1, latitude, longitude)

#       :ets.update_element(:public_ets_agent, record1.uuid, update_values)

#     end,
#     "public_ets_agent - update in agent - batched" => fn ->
#       {latitude, longitude} = Position.random_lat_long()

#       update_values = Test.update_values(record1, latitude, longitude)

#       Agent.update(public_ets_agent_pid, fn _reference ->
#         :ets.update_element(:public_ets_agent, record1.uuid, update_values)
#       end)
#     end,
#     "protected_ets_agent - update in agent - batched" => fn ->
#       {latitude, longitude} = Position.random_lat_long()

#       update_values = Test.update_values(record1, latitude, longitude)

#       Agent.update(protected_ets_agent_pid, fn _reference ->
#         :ets.update_element(:protected_ets_agent, record1.uuid, update_values)
#       end)
#     end,
  },
  time: 10,
  memory_time: 2
)

