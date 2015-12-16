defmodule Gallery.GetHandler do
  def init(req, _opts) do
    %{:recipient => r, :sender => s} =
      :cowboy_req.match_qs([{:recipient, &sanitise/1, false},
                            {:sender, &sanitise/1, false}],
                           req)
    {:ok, reply(r, s, req), nil}
  end

  def reply(false, false, req) do
    case select_form(false, false) do
      {:ok, html} ->
        :cowboy_req.reply(
          200,
          [],
          "<html><title>Image Gallery</title><body>"
          <> html
          <> "</body></html>",
          req)
      false ->
        :cowboy_req.reply(400, [], "", req)
    end
  end

  def reply(recipient, sender, req) do
    case {select_form(recipient, sender),
          Gallery.Master.get_images(recipient, sender)}
      do
      {{:ok, html}, {:ok, list}} ->
        :cowboy_req.reply(
          200,
          [],
          "<html><title>Image Gallery</title><body>"
          <> html
          <>
          Enum.reduce(
            list,
            "",
            fn(x, acc) -> acc <> "<img src=\"" <> x <> "\" />" end)
        <> "</body></html>",
        req)
      _ ->
        :cowboy_req.reply(400, [], "", req)
    end
  end

  def select_form(recipient, sender) do
    case Gallery.Master.get_keys do
      {:ok, recipients, senders} ->
        {:ok,
         "<form action=\"gallery\">Recipient: <select name=\"recipient\">"
         <> list_options(recipients, recipient)
         <> "</select><br />Sender: <select name=\"sender\">"
         <> list_options(senders, sender)
         <> "</select><br /><input type=\"submit\" value=\"Submit\" /></form>"}
      false ->
        false
    end
  end

  def list_options(list, item) do
    "<option value=\"false\""
    <> if item do " />" else " selected=\"selected\" />" end
    <>
    Enum.reduce(
      list,
      "",
      fn(x, acc) ->
        acc
        <> "<option value=\"" <> x <> "\""
        <> if x == item do " selected=\"selected\">" else ">" end
        <> x <> "</option>"
      end)
  end

  def sanitise("false"), do: {:true, false}
  def sanitise(_), do: :true
end
