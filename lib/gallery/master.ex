use Database

defmodule Gallery.Master do
  @moduledoc """
  This is the main API to access the images available in the gallery.

  ## API

  There are two functions available:
    * get_keys - get the lists of all existing receivers and senders,

    * get_images - get images from a specific receiver and/or sender.

  ## Internal server design

  The two api functions are handled differently:
    * get_keys - it is assumed that this function will be called very often and
      therefore it cannot access the database.  Instead, the keys are cached in
      the server state.  The cache is updated every minute, which is consitered
      acceptable for the intended purpose.

    * get_images - this is considered a heavy operation thus a separate worker
      process is started to handle each request.  A custom message protocol with
      proper process error handling is used towards the worker processes, and
      this is fully encapsulated in the API call.
  """
  use GenServer

  @spec get_keys(GenServer.server) :: {receivers :: [String.t],
                                       senders :: [String.t]}
  def get_keys(server \\ __MODULE__) do
    GenServer.call(server, :get_keys, :infinity)
  end

  @spec get_images(server   :: GenServer.server,
                   receiver :: String.t | false,
                   sender   :: String.t | false) :: {:ok, [String.t]} | false
  def get_images(server \\ __MODULE__, recipient, sender) do
    case GenServer.call(server, {:request, recipient, sender}, :infinity) do
      {:ok, pid, call_ref} ->
        monitor_ref = Process.monitor(pid)
        receive do
          {^call_ref, reply} ->
            Process.demonitor(monitor_ref)
            receive do
              {_, ^monitor_ref, _, _, _} -> :ok
            after 0                     -> :ok
            end
            reply
          {:DOWN, ^monitor_ref, _pid, _object, _info} ->
            false
        end
      :error ->
        false
    end
  end

  def start_link(worker_sup, opts \\ []) do
    GenServer.start_link(__MODULE__, worker_sup, opts)
  end

  def init(worker_sup) do
    {:ok, tref} = :timer.send_interval(60000, :update_keys)
    {:ok, update_keys(%{worker_sup: worker_sup,
                        receivers: [],
                        senders: [],
                        timer: tref})}
  end

  def terminate(_reason, state) do
    :timer.cancel(state.tref)
  end

  def handle_call({:request, recipient, sender}, from, state) do
    {:reply,
     Gallery.WorkerSupervisor.start_worker(
       state.worker_sup, from, recipient, sender),
     state}
  end

  def handle_call(:get_keys, _from, state) do
    {:reply, {:ok, state.receivers, state.senders}, state}
  end

  def handle_info(:update_keys, state) do
    {:noreply, update_keys(state)}
  end

  def update_keys(state) do
    try do
      %{state |
        receivers: Amnesia.transaction do
          Mail.keys
        end,
        senders: Amnesia.transaction do
          r = Mail.where true, select: sender
          r |> Amnesia.Selection.values |> Enum.uniq
        end}
    catch
      :exit, _ ->
        state
    end
  end
end
