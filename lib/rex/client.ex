defmodule Rex.Client do
  use GenServer
  alias Rex.HandshakeResponse
  alias Rex.LocalStateQueryResponse

  defstruct [:socket, :path, :send_timeout, :recv_timeout]

  def get_current_era(pid \\ __MODULE__) do
    GenServer.call(pid, :get_current_era)
  end

  def start_link(opts) do
    state = %__MODULE__{
      path: Keyword.fetch!(opts, :path),
      send_timeout: Keyword.get(opts, :send_timeout, 4000),
      recv_timeout: Keyword.get(opts, :recv_timeout, 4000)
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state = %__MODULE__{path: path, send_timeout: send_timeout}) do
    opts = [:binary, active: false, send_timeout: send_timeout]

    # Connect to local unix socket on `path`
    {:ok, socket} = :gen_tcp.connect({:local, path}, 0, opts)

    # Handshake Header
    header = <<0, 0, 0, 110, 0, 0, 0, 35>>

    # Handshake Payload
    payload =
      <<130, 0, 167, 25, 128, 10, 4, 25, 128, 11, 4, 25, 128, 12, 4, 25, 128, 13, 4, 25, 128, 14,
        4, 25, 128, 15, 130, 4, 244, 25, 128, 16, 130, 4, 244>>

    :ok = :gen_tcp.send(socket, header <> payload)

    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        # Only works when connecting via Unix socket
        <<_header_todo_investigate::binary-size(8), response_payload::binary>> = full_response

        case CBOR.decode(response_payload) do
          {:ok, decoded, ""} ->
            parsed = HandshakeResponse.parse_response(decoded)
            IO.puts("Handshake successful! #{inspect(parsed)}")

          {:error, reason} ->
            IO.puts("Error decoding handshake response! #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("Handshake failed: #{inspect(reason)}")
    end

    {:ok, %__MODULE__{state | socket: socket}}
  end

  @impl true
  def handle_call(:get_current_era, _from, %{socket: socket} = state) do
    query_acquire_msg_header = <<0, 0, 44, 137, 0, 7, 0, 2>>
    query_acquire_msg_payload = <<129, 8>>

    :ok = :gen_tcp.send(socket, query_acquire_msg_header <> query_acquire_msg_payload)

    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        IO.puts("msgAcquired: #{inspect(full_response)}")

      {:error, reason} ->
        IO.puts("msgAcquired error: #{inspect(reason)}")
    end

    get_current_era_header = <<0, 0, 78, 154, 0, 7, 0, 8>>
    get_current_era_payload = <<130, 3, 130, 0, 130, 2, 129, 1>>

    :ok = :gen_tcp.send(socket, get_current_era_header <> get_current_era_payload)

    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, full_response} ->
        <<_header_todo_investigate::binary-size(8), response_payload::binary>> = full_response

        case CBOR.decode(response_payload) do
          {:ok, decoded, ""} ->
            {:ok, current_era} = LocalStateQueryResponse.parse_response(decoded)
            IO.puts("Current era: #{inspect(current_era)}")
            {:reply, current_era, state}

          {:error, reason} ->
            IO.puts("error decoding #{inspect(reason)}")
            {:reply, 0, state}
        end

      {:error, reason} ->
        IO.puts("Error querying current erra: #{inspect(reason)}")
        {:reply, 0, state}
    end
  end
end
