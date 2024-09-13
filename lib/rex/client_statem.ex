defmodule Rex.ClientStatem do
  @moduledoc """
  Connects to a Cardano node via local UNIX socket using the Node-to-Client protocol
  """
  @behaviour :gen_statem

  alias Rex.HandshakeResponse
  alias Rex.LocalStateQueryResponse
  alias Rex.Messages

  require Logger

  defstruct [:path, :socket, :network]

  ##############
  # Public API #
  ##############

  def query(pid \\ __MODULE__, query_name) do
    :gen_statem.call(pid, {:request, query_name})
  end

  def start_link(opts) do
    data = %__MODULE__{
      path: Keyword.fetch!(opts, :socket_path),
      network: Keyword.get(opts, :network, :mainnet),
      socket: nil
    }

    :gen_statem.start_link({:local, __MODULE__}, __MODULE__, data, [])
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
  def callback_mode, do: :state_functions

  @impl true
  def init(data) do
    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  def disconnected(:internal, :connect, %__MODULE__{path: path} = data) do
    opts = [:binary, active: false, send_timeout: 4_000]

    # Connect to local unix socket on `path`
    case :gen_tcp.connect({:local, path}, 0, opts) do
      {:ok, socket} ->
        data = %__MODULE__{data | socket: socket}
        actions = [{:next_event, :internal, :establish}]
        {:next_state, :connected, data, actions}

      {:error, reason} ->
        Logger.error("Error reaching socket #{inspect(reason)}")
        {:next_state, :disconnected, data}
    end
  end

  def disconnected({:call, from}, _command, data) do
    actions = [{:reply, from, {:error, :disconnected}}]
    {:keep_state, data, actions}
  end

  def connected(:internal, :establish, %__MODULE{socket: socket, network: network} = data) do
    :ok = :gen_tcp.send(socket, Messages.handshake(network))

    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        {:ok, _handshake} = HandshakeResponse.parse_response(full_response)
        {:next_state, :established, data}

      {:error, reason} ->
        Logger.error("Error establishing connection #{inspect(reason)}")
        {:next_state, :disconnected, data}
    end
  end

  def established(
        {:call, from},
        {:request, :get_current_era},
        %__MODULE__{socket: socket} = data
      ) do
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
          {:next_state, :disconnected, data}
      end

    # Must release to allow future calls
    :ok = :gen_tcp.send(socket, Messages.msg_release())

    reply
  end
end
