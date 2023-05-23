defmodule WhenToProcess.RidesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WhenToProcess.Rides` context.
  """

  @doc """
  Generate a driver.
  """
  def driver_fixture(attrs \\ %{}) do
    {:ok, driver} =
      attrs
      |> Enum.into(%{
        latitude: 120.5,
        longitude: 120.5,
        ready_for_passengers: true
      })
      |> WhenToProcess.Rides.create_driver()

    driver
  end
end
