defmodule ExNode.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExNode.Client, client_opts()}
    ]

    opts = [strategy: :one_for_one, name: ExNode.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp client_opts do
    [path: System.fetch_env!("NODE_SOCKET_PATH")]
  end
end
