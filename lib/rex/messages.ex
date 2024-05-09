defmodule Rex.Messages do
  def handshake do
    header = <<0, 0, 0, 110, 0, 0, 0, 35>>

    payload =
      <<130, 0, 167, 25, 128, 10, 4, 25, 128, 11, 4, 25, 128, 12, 4, 25, 128, 13, 4, 25, 128, 14,
        4, 25, 128, 15, 130, 4, 244, 25, 128, 16, 130, 4, 244>>

    header <> payload
  end

  def msg_acquire do
    header = <<0, 0, 44, 137, 0, 7, 0, 2>>
    payload = <<129, 8>>

    header <> payload
  end

  def get_current_era do
    header = <<0, 0, 78, 154, 0, 7, 0, 8>>
    payload = <<130, 3, 130, 0, 130, 2, 129, 1>>

    header <> payload
  end
end
