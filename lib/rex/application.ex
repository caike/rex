defmodule Rex.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Rex.Client, client_opts()},
      {Rex.ClientStatem, client_opts()}
    ]

    opts = [strategy: :one_for_one, name: Rex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @default_node_socket_path "/tmp/cardano-node.socket"

  defp client_opts do
    [
      socket_path: System.get_env("CARDANO_NODE_SOCKET_PATH", @default_node_socket_path),
      network: :mainnet
    ]
  end
end
