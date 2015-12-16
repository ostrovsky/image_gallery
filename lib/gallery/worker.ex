use Amnesia
use Database

defmodule Gallery.Worker do
  @docmodule """
  This module implements a custom simple worker that can be plugged into
  the standard supervision tree.  It uses Erlang proc_lib instead of GenServer
  behaviour to be more light-weight.  This simple version provides only the init
  function and lacks system_continue/3, system_terminate/4 for handling of
  system messages, since it cannot be really interrupted.
  """
  def start_link(from, recipient, sender) do
    :proc_lib.start_link(__MODULE__, :init, [self(), from, recipient, sender])
  end

  def init(parent, {pid, ref}, recipient, sender) do
    :proc_lib.init_ack(parent, {:ok, self(), ref})
    deb = :sys.debug_options([])
    do_work(parent, deb, {pid, ref, recipient, sender})
  end

  @doc """
  Perfrom the heavy work: database lookup using three different functions
  for better performance (using a key, an index, or full select).

  TODO: This function should probably handle any system messages.
  """
  def do_work(_parent, _deb, {pid, ref, recipient, sender}) do
    try do
      result = cond do
        recipient != false and sender != false ->
          do_select(recipient, sender)
        recipient ->
          do_read(recipient)
        sender ->
          do_read_at(sender)
        true ->
          []
      end
      send(pid, {ref, {:ok, result}})
    catch
      :exit, _ ->
         false
    end
  end

  def do_select(r, s) do
    Amnesia.transaction do
      r = Mail.where recipient == r and sender == s, select: files
      r |> Amnesia.Selection.values |> Enum.flat_map fn(x) -> x end
    end
  end

  def do_read(recipient) do
    Amnesia.transaction do
      Mail.read(recipient) |> Enum.flat_map fn(x) -> x.files end
    end
  end

  def do_read_at(sender) do
    Amnesia.transaction do
      Mail.read_at(sender, :sender) |> Enum.flat_map fn(x) -> x.files end
    end
  end
end
