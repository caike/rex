defmodule Rex.Messages do
  @moduledoc """
  This module returns protocol messages ready to be sent to the server.
  """

  def handshake(network) do
    case network do
      :mainnet ->
        header = [<<0, 0, 1, 52, 0, 0, 0, 63>>]

        payload = [
          <<130, 0, 167, 25, 128, 10, 26, 45, 150, 74, 9, 25, 128, 11, 26, 45, 150, 74, 9, 25,
            128, 12, 26, 45, 150, 74, 9, 25, 128, 13, 26, 45, 150, 74, 9, 25, 128, 14, 26, 45,
            150, 74, 9, 25, 128, 15, 130, 26, 45, 150, 74, 9, 244, 25, 128, 16, 130, 26, 45, 150,
            74, 9, 244>>
        ]

        [header | payload]

      :sanchonet ->
        header = [<<0, 0, 0, 110, 0, 0, 0, 35>>]

        payload =
          [
            <<130, 0, 167, 25, 128, 10, 4, 25, 128, 11, 4, 25, 128, 12, 4, 25, 128, 13, 4, 25,
              128, 14, 4, 25, 128, 15, 130, 4, 244, 25, 128, 16, 130, 4, 244>>
          ]

        [header | payload]
    end
  end

  def msg_acquire do
    header = [<<0, 0, 44, 137, 0, 7, 0, 2>>]
    payload = [<<129, 8>>]

    [header | payload]
  end

  def msg_release do
    header = [<<0, 0, 167, 211, 0, 7, 0, 2>>]
    payload = [<<129, 5>>]

    [header | payload]
  end

  def get_current_era do
    header = [<<0, 0, 78, 154, 0, 7, 0, 8>>]
    payload = [<<130, 3, 130, 0, 130, 2, 129, 1>>]

    [header | payload]
  end
end
