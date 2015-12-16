use Amnesia
use Database

defmodule Gallery do
  use Application

  def start(_type, _args) do
    # Prepare the database, and possibly create a new one
    Amnesia.Schema.create
    Amnesia.start
    Database.create(disk: [node])
    Database.wait
    # Start the web-server
    dispatch = :cowboy_router.compile([
      {:_, [{"/post", Gallery.PostHandler, []},
            {"/gallery", Gallery.GetHandler, []},
            {"/images/[...]", :cowboy_static, {:dir, "images"}}]}])
    {:ok, _} = :cowboy.start_http(:http, 100,
                                  [port: 8080],
                                  [env: [dispatch: dispatch]])
    # Start the Gallery API
    Gallery.Supervisor.start_link
  end
end
