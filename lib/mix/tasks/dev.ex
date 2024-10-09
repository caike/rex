defmodule Mix.Tasks.Dev do
  use Mix.Task

  def run(_) do
    Application.ensure_all_started(:rex)

    msg =
      Rex.Messages.Handshake.propose_version_message([10, 11, 12, 13, 14, 15, 16], :mainnet)

    dbg(msg)
    dbg(CBOR.decode(msg))

    :ok
  end
end
