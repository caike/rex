defmodule Rex.ClientStatem do
  @moduledoc """
  Connects to a Cardano node via local UNIX socket using the Node-to-Client protocol
  """
  @behaviour :gen_statem

  alias Rex.HandshakeResponse
  alias Rex.LocalStateQueryResponse
  alias Rex.Messages

  require Logger

  @basic_tcp_opts [:binary, active: false, send_timeout: 4_000]

  defstruct [:node_port, :node_url, :path, :socket, :network, queue: :queue.new()]

  ##############
  # Public API #
  ##############

  def query(pid \\ __MODULE__, query_name) do
    :gen_statem.call(pid, {:request, query_name})
  end

  def start_link(opts) do
    data = %__MODULE__{
      node_port: Keyword.fetch!(opts, :node_port),
      node_url: Keyword.fetch!(opts, :node_url),
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

  def disconnected(:internal, :connect, %__MODULE__{node_url: node_url, path: path} = data) do
    # Connect to local unix socket on `path`
    case tcp_lib(data.path).connect(
           node_path(%{socket_path: path, node_url: node_url}),
           node_port(data.path),
           tcp_opts(data.path, node_url)
         ) do
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
    :ok = tcp_lib(data.path).send(socket, Messages.handshake(network))

    case tcp_lib(data.path).recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        {:ok, _handshake} = HandshakeResponse.parse_response(full_response)

        actions = [{:next_event, :internal, :acquire_agency}]
        {:next_state, :established_no_agency, data, actions}

      {:error, reason} ->
        Logger.error("Error establishing connection #{inspect(reason)}")
        {:next_state, :disconnected, data}
    end
  end

  def established_no_agency(:internal, :acquire_agency, %__MODULE__{socket: socket} = data) do
    :ok = tcp_lib(data.path).send(socket, Messages.msg_acquire())
    {:ok, _acquire_response} = tcp_lib(data.path).recv(socket, 0, 5_000)
    {:next_state, :established_has_agency, data}
  end

  def established_no_agency(:info, {:tcp_closed, socket}, %__MODULE__{socket: socket} = data) do
    Logger.error("Connection closed")
    {:next_state, :disconnected, data}
  end

  def established_has_agency(
        {:call, from},
        {:request, :get_current_era},
        %__MODULE__{socket: socket} = data
      ) do
    :ok = setopts_lib(data.path).setopts(socket, active: :once)
    :ok = tcp_lib(data.path).send(socket, Messages.get_current_era())
    data = update_in(data.queue, &:queue.in(from, &1))
    {:keep_state, data}
  end

  def established_has_agency(
        :info,
        {_tcp_or_ssl, socket, bytes},
        %__MODULE__{socket: socket} = data
      ) do
    {:ok, current_era} = LocalStateQueryResponse.parse_response(bytes)
    {{:value, caller}, data} = get_and_update_in(data.queue, &:queue.out/1)
    # This action issues the response back to the clinet
    actions = [{:reply, caller, {:ok, current_era}}]
    {:keep_state, data, actions}
  end

  def established_has_agency(:info, {:tcp_closed, socket}, %__MODULE__{socket: socket} = data) do
    Logger.error("Connection closed")
    {:next_state, :disconnected, data}
  end

  defp node_path(%{socket_path: nil, node_url: nil}), do: raise("No node path or URL provided")
  defp node_path(%{socket_path: nil, node_url: url}), do: ~c"#{url}"
  defp node_path(%{socket_path: path, node_url: _}), do: {:local, ~c"#{path}"}

  defp node_port(nil), do: 9443
  defp node_port(_), do: 0

  defp tcp_lib(nil), do: :ssl
  defp tcp_lib(_), do: :gen_tcp

  defp tcp_opts(nil, url),
    do:
      @basic_tcp_opts ++
        [
          verify: :verify_none,
          server_name_indication: ~c"#{url}",
          secure_renegotiate: true
        ]

  defp tcp_opts(_, _), do: @basic_tcp_opts

  defp setopts_lib(nil), do: :ssl
  defp setopts_lib(_), do: :inet
end
