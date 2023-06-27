defmodule WhenToProcess.Rides.IndividualState do
  @callback get(module(), String.t()) :: term()
  @callback reload(term()) :: term()
end
