use Amnesia
use Database

defmodule Gallery.MasterTest do
  use ExUnit.Case

  test "Master updates keys once a minute" do
    r_key = :base64.encode(:crypto.strong_rand_bytes(64))
    s_key = :base64.encode(:crypto.strong_rand_bytes(64))
    mail = %Mail{recipient: r_key,
                 sender: s_key,
                 subject: "",
                 body: "",
                 files: []}
    {:ok, old_interval} = GenServer.call(Gallery.Master,
                                         {:set_update_interval, 100},
                                         :infinity)
    {:ok, old_recipients, old_senders} = Gallery.Master.get_keys
    Amnesia.transaction do: Mail.write(mail)
    :timer.sleep(200)
    {:ok, add_recipients, add_senders} = Gallery.Master.get_keys
    Amnesia.transaction do: Mail.delete(r_key)
    :timer.sleep(200)
    {:ok, del_recipients, del_senders} = Gallery.Master.get_keys
    {:ok, 100} = GenServer.call(Gallery.Master,
                                {:set_update_interval, old_interval},
                                :infinity)
    assert Enum.member?(add_recipients -- old_recipients, r_key)
    assert Enum.member?(add_senders -- old_senders, s_key)
    refute Enum.member?(del_recipients, r_key)
    refute Enum.member?(del_senders, s_key)
  end
end
