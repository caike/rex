defmodule Rex.Client do
  use GenServer
  alias Rex.HandshakeResponse
  alias Rex.LocalStateQueryResponse
  alias Rex.Messages

  defstruct [:socket, :path, :network, :send_timeout, :recv_timeout, :handshake_response]

  def query(pid \\ __MODULE__, query_name) do
    GenServer.call(pid, {:local_state_query, query_name})
  end

  def start_link(opts) do
    state = %__MODULE__{
      path: Keyword.fetch!(opts, :socket_path),
      network: Keyword.get(opts, :network, :mainnet),
      send_timeout: Keyword.get(opts, :send_timeout, 4000),
      recv_timeout: Keyword.get(opts, :recv_timeout, 4000)
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state = %__MODULE__{path: path, network: network, send_timeout: send_timeout}) do
    opts = [:binary, active: false, send_timeout: send_timeout]

    # Connect to local unix socket on `path`
    {:ok, socket} = :gen_tcp.connect({:local, path}, 0, opts)

    :ok = :gen_tcp.send(socket, Messages.handshake(network))

    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        {:ok, handshake} = HandshakeResponse.parse_response(full_response)
        {:ok, %__MODULE__{state | socket: socket, handshake_response: handshake}}

      {:error, reason} ->
        IO.puts("Handshake failed: #{inspect(reason)}")
        {:ok, %__MODULE__{state | socket: socket}}
    end
  end

  @impl true
  def handle_call({:local_state_query, :get_current_era}, _from, %{socket: socket} = state) do
    :ok = :gen_tcp.send(socket, Messages.msg_acquire())

    # Must acquire prior to querying
    {:ok, _acquire_response} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, Messages.get_current_era())

    reply =
      case :gen_tcp.recv(socket, 0, 5_000) do
        {:ok, full_response} ->
          {:ok, current_era} = LocalStateQueryResponse.parse_response(full_response)
          {:reply, current_era, state}

        {:error, _reason} ->
          {:reply, 0, state}
      end

    # Must release to allow future calls
    :ok = :gen_tcp.send(socket, Messages.msg_release())

    reply
  end
end
