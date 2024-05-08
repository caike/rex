defmodule ExNode.Client do
  use GenServer
  alias ExNode.HandshakeResponse

  defstruct [:socket, :path, :send_timeout, :recv_timeout]

  def start_link(opts) do
    state = %__MODULE__{
      path: Keyword.fetch!(opts, :path),
      send_timeout: Keyword.get(opts, :send_timeout, 4000),
      recv_timeout: Keyword.get(opts, :recv_timeout, 4000)
    }

    GenServer.start_link(__MODULE__, state)
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
end
