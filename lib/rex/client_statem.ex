defmodule Rex.ClientStatem do
  @behaviour :gen_statem

  alias Rex.HandshakeResponse
  alias Rex.LocalStateQueryResponse
  alias Rex.Messages

  defstruct [:path, :socket, :network]

  ##############
  # Public API #
  ##############

  def query(pid \\ __MODULE__, query_name) do
    :gen_statem.call(pid, {:request, query_name})
  end

  def start_link(opts) do
    state = %__MODULE__{
      path: Keyword.fetch!(opts, :path),
      network: Keyword.get(opts, :network, :mainnet),
      socket: nil
    }

    :gen_statem.start_link({:local, __MODULE__}, __MODULE__, state, [])
  end

  #############
  # Callbacks #
  #############

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @impl true
  def callback_mode do
    :state_functions
  end

  @impl true
  def init(initial_state) do
    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, initial_state, actions}
  end

  def disconnected(:internal, :connect, %{path: path, network: network} = state) do
    opts = [:binary, active: false, send_timeout: 4_000]

    # Connect to local unix socket on `path`
    {:ok, socket} = :gen_tcp.connect({:local, path}, 0, opts)

    :ok = :gen_tcp.send(socket, Messages.handshake(network))

    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        {:ok, _handshake} = HandshakeResponse.parse_response(full_response)
        {:next_state, :connected, %__MODULE__{state | socket: socket}}

      {:error, _reason} ->
        actions = [{:next_event, :internal, :connect}]
        {:keep_state_and_data, actions}
    end
  end

  def connected({:call, from}, {:request, :get_current_era}, %{socket: socket} = _state) do
    :ok = :gen_tcp.send(socket, Messages.msg_acquire())

    # Must acquire prior to querying
    {:ok, _acquire_response} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, Messages.get_current_era())

    reply =
      case :gen_tcp.recv(socket, 0, 5_000) do
        {:ok, full_response} ->
          {:ok, current_era} = LocalStateQueryResponse.parse_response(full_response)
          {:keep_state_and_data, [{:reply, from, current_era}]}

        {:error, _reason} ->
          {:keep_state_and_data, [{:reply, from, 0}]}
      end

    # Must release to allow future calls
    :ok = :gen_tcp.send(socket, Messages.msg_release())

    reply
  end
end
