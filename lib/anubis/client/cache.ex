defmodule Anubis.Client.Cache do
  @moduledoc false

  alias Anubis.Client.JSONSchemaConverter

  @type table :: :ets.table()

  # Public API

  @doc """
  Creates a per-client cache table and returns its reference.

  The table is anonymous (no `:named_table`) and `:private`, so it is
  owned solely by the calling process and can never collide with the
  table of another client that happens to share a `client_info["name"]`.
  Owned tables are reclaimed automatically when the owner process dies.
  """
  @spec new :: table()
  def new do
    :ets.new(:anubis_tool_validators, [:private, :set, read_concurrency: true])
  end

  @doc """
  Stores tool output validators in the cache.
  Clears existing validators before storing new ones.
  """
  @spec put_tool_validators(table(), tools :: list(map())) :: :ok
  def put_tool_validators(table, tools) when is_list(tools) do
    :ets.delete_all_objects(table)

    tools
    |> Enum.filter(& &1["outputSchema"])
    |> Enum.flat_map(&fetch_tool_validator/1)
    |> then(&:ets.insert(table, &1))

    :ok
  end

  defp fetch_tool_validator(%{"outputSchema" => s, "name" => name}) when is_map(s) do
    case JSONSchemaConverter.validator(s) do
      {:ok, validator} -> [{name, validator}]
      {:error, _errors} -> []
    end
  end

  @doc """
  Gets a tool output validator from the cache.
  """
  @spec get_tool_validator(table(), tool_name :: String.t()) ::
          JSONSchemaConverter.validator() | nil
  def get_tool_validator(table, tool_name) when is_binary(tool_name) do
    case :ets.lookup(table, tool_name) do
      [{^tool_name, validator}] -> validator
      [] -> nil
    end
  end

  @doc """
  Clears all tool validators from the cache.
  """
  @spec clear_tool_validators(table()) :: :ok
  def clear_tool_validators(table) do
    :ets.delete_all_objects(table)
    :ok
  end

  @doc """
  Deletes the cache table. Should be called when the client process
  terminates (owned tables are also reclaimed automatically on exit).
  """
  @spec cleanup(table()) :: :ok
  def cleanup(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
    :ok
  end
end
