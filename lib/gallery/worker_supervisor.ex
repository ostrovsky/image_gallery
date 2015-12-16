defmodule Gallery.WorkerSupervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_worker(server \\ __MODULE__, from, recipient, sender) do
    Supervisor.start_child(server, [from, recipient, sender])
  end

  def init(:ok) do
    children = [
      worker(Gallery.Worker, [], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
