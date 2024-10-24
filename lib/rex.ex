defmodule Rex do
  @moduledoc false

  def get_current_era do
    Rex.ClientStatem.query(:get_current_era) |> IO.inspect()
  end
end
