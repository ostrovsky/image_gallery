use Amnesia
use Database

defmodule Gallery.PostHandler do
  @moduledoc """
  This is a cowboy handler module that is responsible for handling mails POST:ed
  by the mailgun.com system.  Only e-mails with at least one image (with
  supported type, namely those supported by erl_img) are accepted.  All images
  with supported type  are resized to fit 400x300 and saved on disk before
  meta-data (e-mail) is saved in the database.  The original image file name
  is concatenated with the MD5 checksum of the original image to get a unique
  file name.

  The choice of erl_img was based on a desire to keep data in memory for as long
  as possible and use the slow file system as little as possible.
  """
  require Record
  Record.defrecord :erl_image, Record.extract(
    :erl_image, from: "deps/erl_img/include/erl_img.hrl")

  @doc """
  Simple cowboy request handler based on mailgun.com POST routing API.
  """
  def init(req, _opts) do
    reply = case parse_mail(req) |> resize_and_save_images do
              {:ok, mail, req2} ->
                Amnesia.transaction do: Mail.write(mail)
                :cowboy_req.reply(
                  200, [{"content-type", "text/plain"}], "Thank you.", req2)
              {:false, req2} ->
                :cowboy_req.reply(
                  406, [{"content-type", "text/plain"}], "Do not understand.",
                  req2)
            end
    {:ok, reply, nil}
  end

  @doc """
  Parse only messages with attachments: those must be multipart/form-data.
  """
  def parse_mail(req) do
    case :cowboy_req.parse_header("content-type", req) do
      {"multipart", "form-data", _} -> parse_multipart(req, %Mail{files: []})
      _                             -> {:false, req}
    end
  end

  @doc """
  Parse the e-mail data needed as the mata-data for image files.  Parse
  the attached image files, too.

  Note: This function breaks the spec for %Mail{files: [String.t]} since it
  actually returns %Mail{files: [{String.t, binary]}.
  """
  def parse_multipart(req, mail) do
    case :cowboy_req.part(req) do
      {:ok, headers, req2} ->
        case :cow_multipart.form_data(headers) do
          {:data, "recipient"} ->
            {:ok, recipient, req3} = :cowboy_req.part_body(req2)
            parse_multipart(req3, %{mail | recipient: recipient})
          {:data, "sender"} ->
            {:ok, sender, req3} = :cowboy_req.part_body(req2)
            parse_multipart(req3, %{mail | sender: sender})
          {:data, "subject"} ->
            {:ok, subject, req3} = :cowboy_req.part_body(req2)
            parse_multipart(req3, %{mail | subject: subject})
          {:data, "body-plain"} ->
            {:ok, body, req3} = :cowboy_req.part_body(req2)
            parse_multipart(req3, %{mail | body: body})
          {:file, _field_name, file_name, "image/" <> image_type, _encoding} ->
            {content, req3} = stream_file(req2, "")
            if supported_type?(image_type) do
              parse_multipart(
                req3, %{mail | files: [{file_name, content} | mail.files]})
            else
              parse_multipart(req3, mail)
            end
          _ ->
            parse_multipart(req2, mail)
        end
      {:done, req2} ->
        {:ok, mail, req2}
    end
  end

  def stream_file(req, acc) do
    case :cowboy_req.part_body(req) do
      {:ok, body, req2}   -> {acc <> body, req2}
      {:more, body, req2} -> stream_file(req2, acc <> body)
    end
  end

  def supported_type?("bmp"), do: true
  def supported_type?("gif"), do: true
  def supported_type?("jpeg"), do: true
  def supported_type?("png"), do: true
  def supported_type?("tga"), do: true
  def supported_type?("tiff"), do: true
  def supported_type?("xmp"), do: true
  def supported_type?(_), do: false

  @doc """
  Resize and save all the attached images.

  Note: This function takes the "mis-typed" %Mail{files: [{String.t, binary}]}
  and returns the correctly typed %Mail{files: [String.t]}.
  """
  def resize_and_save_images({:ok, mail, req}) do
    if length(mail.files) > 0 do
      {:ok, %{mail | files: Enum.map(mail.files, &resize_and_save/1)}, req}
    else
      {:false, req}
    end
  end

  def resize_and_save_images(other) do
    other
  end

  @doc """
  Perform the actual resizing and save.

  TODO: better error handling.
  """
  def resize_and_save({file_name, content}) do
    full_file_name = "images/" <> md5(content) <> "." <> file_name <> ".png"
    {:ok, img} = :erl_img.load(content)
    if erl_image(img, :width) > 400 or erl_image(img, :height) > 300 do
      scale_factor = min(400.0 / erl_image(img, :width),
                         300.0 / erl_image(img, :height))
      img = :erl_img.scale(img, scale_factor)
    end
    img = erl_image(img, type: :image_png)
    :erl_img.save(to_char_list(full_file_name), img)
    # IO.inspect(img)
    # {:ok, file} = File.open(full_file_name, [:write])
    # IO.binwrite(file, content)
    # File.close(file)
    full_file_name
  end

  @doc """
  Compute the MD5 checksum and return a string that looks as the strings
  returned by md5sum command, though all upper case.

  ## Examples

    iex> Gallery.PostHandler.md5("abcd")
    "E2FC714C4727EE9395F324CD2E7F331F"

  """
  def md5(content) do
    Enum.map(
      :erlang.md5(content) |> :erlang.binary_to_list,
      fn(x) ->
        list = Integer.to_char_list(x, 16)
        if length(list) == 1 do
          [48 | list]
        else
          list
        end
      end)
    |> :lists.flatten
    |> to_string
  end
end
