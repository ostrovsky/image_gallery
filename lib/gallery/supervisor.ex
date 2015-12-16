defmodule Gallery.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  @worker_supervisor Gallery.WorkerSupervisor
  @master Gallery.Master

  def init(:ok) do
    children = [
      supervisor(Gallery.WorkerSupervisor, [[name: @worker_supervisor]]),
      worker(Gallery.Master, [@worker_supervisor, [name: @master]])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
