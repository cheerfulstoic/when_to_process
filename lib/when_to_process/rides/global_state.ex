defmodule WhenToProcess.Rides.GlobalState do
  @callback list(module()) :: [term()]
  @callback count(module()) :: integer()
  @callback list_nearby(module(), WhenToProcess.Rides.position(), integer(), function(), integer()) :: [term()]
  @callback get(module(), String.t()) :: term()
end

