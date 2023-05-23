# WhenToProcess

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

# NOTES:

 * `Driver` and `Passenger` could potentially just be `Person`/`User`, but trying not to worry about the larger picture
 * Simplifications because they aren't part of what I'm trying to test:
   * Not trying to follow roads
   * When dealing with distances, using "as the crow flies" distances
   * Just dealing with one city (it might make sense in the future to only broadcast events to drivers in the same area as the request)
     * Maybe I should choose drivers to assign to the request?  And maybe just start with 2 or 3, but expand if nobody responds (??)
