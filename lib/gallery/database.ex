require Amnesia
use Amnesia

defdatabase Database do
  @doc """
  The API will allow lookup based on recipient and/or sender.  Thus recipient
  is going to be the key and sender has an extra index for faster access.
  The database only stores meta-data about each image file.  The image files
  themselves are stored in the file system.
  """
  deftable Mail,
  [:recipient, :sender, :subject, :body, :files],
  index: [:sender],
  type: :bag do
    @type t :: %Mail{recipient: String.t,
                     sender: String.t,
                     subject: String.t,
                     body: String.t,
                     files: [String.t]}
  end
end
