defmodule WhenToProcessWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: WhenToProcess.PubSub
end


