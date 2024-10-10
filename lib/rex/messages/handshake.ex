defmodule Rex.Messages.Handshake do
  @moduledoc """
  Builds handshake messages for node-to-client communication.
  """

  alias Rex.Messages.Util

  @type network_type :: :mainnet | :preprod | :preview | :sanchonet

  @msg_propose_versions 0
  @msg_accept_version 1
  @msg_refuse 2
  # @msg_query_reply 3

  @network_magic [
    mainnet: 764_824_073,
    preprod: 1,
    preview: 2,
    sanchonet: 4
  ]

  @version_numbers %{
    9 => 32777,
    10 => 32778,
    11 => 32779,
    12 => 32780,
    13 => 32781,
    14 => 32782,
    15 => 32783,
    16 => 32784,
    17 => 32785
  }

  @doc """
  Version numbers must be unique and appear in ascending order.
  """
  @spec propose_version_message([integer()], network_type) :: binary()
  def propose_version_message(versions, network) do
    payload =
      [
        @msg_propose_versions,
        build_version_fragments(versions |> Enum.sort(), network)
      ]
      |> CBOR.encode()

    header(payload) <> payload
  end

  def validate_propose_version_response(response) do
    %{payload: payload} = Util.plex(response)

    case CBOR.decode(payload) do
      {:ok, [@msg_accept_version, version, [_magic, _query]], ""} ->
        {:ok, version}

      {:ok, [@msg_refuse, reason], ""} ->
        {:refused, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_version_fragments(versions, network),
    do:
      Enum.reduce(versions, %{}, fn version, acc ->
        Map.merge(acc, build_single_version_fragment(version, network))
      end)

  defp build_single_version_fragment(version, network) when version >= 15,
    do: %{@version_numbers[version] => [@network_magic[network], false]}

  defp build_single_version_fragment(version, network),
    do: %{@version_numbers[version] => @network_magic[network]}

  # middle 16 bits are: 1 bit == 0 for initiator and 15 bits for the mini protocol ID (0)
  defp header(payload),
    do: <<header_timestamp()::32>> <> <<0, 0>> <> <<byte_size(payload)::unsigned-16>>

  # Returns the lower 32 bits of the system's monotonic time in microseconds
  defp header_timestamp(),
    do:
      System.monotonic_time(:microsecond)
      |> Bitwise.band(0xFFFFFFFF)
end
