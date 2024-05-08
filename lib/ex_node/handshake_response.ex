defmodule ExNode.HandshakeResponse do
  defstruct [:type, :version_number, :network_magic, :query]

  def parse_response([1, version_number, [network_magic, query] = node_to_client_version_data]) do
    with true <- is_valid_version_number(version_number),
         true <- is_valid_version_data(node_to_client_version_data) do
      {
        :ok,
        %__MODULE__{
          type: :msg_accept_version,
          version_number: version_number,
          network_magic: network_magic,
          query: query
        }
      }
    else
      _ ->
        {:error, :invalid_data}
    end
  end

  def parse_response(_), do: {:error, :unsupported_message_type}

  # Validates version number according to CDDL definition (32783 or 32784)
  @version_numbers [32783, 32784]
  defp is_valid_version_number(version_number) do
    version_number in @version_numbers
  end

  # Check if the node to client version data matches expected format
  defp is_valid_version_data([network_magic, query]) do
    is_integer(network_magic) and is_boolean(query)
  end

  defp is_valid_version_data(_), do: false
end
