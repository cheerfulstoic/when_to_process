defmodule WhenToProcessWeb.Router do
  use WhenToProcessWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {WhenToProcessWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]

    post "/drivers", WhenToProcessWeb.DriverController, :create
    post "/setup_drivers/:count", WhenToProcessWeb.DriverController, :setup_drivers
  end

  scope "/", WhenToProcessWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/driver", DriverLive, :index

    live "/passenger", PassengerLive, :index

    live "/overview", OverviewLive, :index

    # State:
    # ready_for_passengers: true/false
    # passenger_id: <int foreign key>
    # Virtual: online == ready_for_passengers || passenger_id
    #
    # Client events:
    # * "go online" (ready_for_passengers: true)
    # * "no more passengers" (ready_for_passengers: false)
    # * "picked up passenger xxx" (passenger_id: xxx)
    # * "update location" (latitude / longitude set to values)
    # * "accept ride request" (passenger_id is set - or maybe "ride" gets driver_id)
    # * "request ride request" (...)
    # * "send message to passenger" (message is delivered)
    # Server events:
    # * "here is a ride request".  Response:
    #   * lat/long of passenger
    #   * distance from driver
    #   * lat/long of destination
    #   * distance of trip
    #   * value of the ride
    #   * passenger info (including name, number of rides, average review rating)
    #   * how many drivers have looked at the request)
    # * Update about ride (how many drivers have looked)

    # send a review for a driver
    # send a review for a passenger
    # get notifications ("You've received a $3.00 tip", )
    #
    # Earnings / stats summary (something which would have more than just a process' state)
  end

  # Other scopes may use custom stacks.
  # scope "/api", WhenToProcessWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:when_to_process, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WhenToProcessWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
