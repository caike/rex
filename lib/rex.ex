defmodule Rex do
  @moduledoc """
  Documentation for `Rex`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Rex.hello()
      :world

  """
  def hello do
    :world
  end

  def get_current_era do
    Rex.Client.get_current_era()
  end
end
