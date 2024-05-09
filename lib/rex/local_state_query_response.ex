defmodule Rex.LocalStateQueryResponse do
  def parse_response([4, response]) do
    {:ok, response}
  end

  def parse_response(_) do
    {:error, :invalid_response}
  end
end
