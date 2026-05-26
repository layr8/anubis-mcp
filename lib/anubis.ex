defmodule Anubis do
  @moduledoc false

  import Peri

  alias Anubis.Server.Transport.SSE, as: ServerSSE
  alias Anubis.Server.Transport.STDIO, as: ServerSTDIO
  alias Anubis.Server.Transport.StreamableHTTP, as: ServerStreamableHTTP
  alias Anubis.Transport.SSE, as: ClientSSE
  alias Anubis.Transport.STDIO, as: ClientSTDIO
  alias Anubis.Transport.StreamableHTTP, as: ClientStreamableHTTP

  # Built-in transports always available.
  @builtin_client_transports [ClientSTDIO, ClientSSE, ClientStreamableHTTP]
  @builtin_server_transports [ServerSTDIO, ServerStreamableHTTP, ServerSSE]

  # Test-only transports the SDK's own test suite uses.
  @test_client_transports if Mix.env() == :test,
                            do: [StubTransport, Anubis.MockTransport, BufferedMockTransport],
                            else: []
  @test_server_transports if Mix.env() == :test, do: [StubTransport], else: []

  defschema :client_transport,
    layer: {:required, {:custom, &Anubis.validate_client_transport/1}},
    name: {:required, get_schema(:process_name)}

  defschema :server_transport,
    layer: {:required, {:custom, &Anubis.validate_server_transport/1}},
    name: {:required, get_schema(:process_name)}

  @doc """
  Validate that `layer` is an allowed client transport module.

  Allowed = the built-in transports (`STDIO`, `SSE`, `StreamableHTTP`),
  the test-only transports when running under `MIX_ENV=test`, AND any
  modules the host application has opted in via:

      config :anubis_mcp, :extra_client_transports, [MyApp.MyTransport]

  Custom transports must implement `Anubis.Transport.Behaviour`.
  """
  def validate_client_transport(layer) when is_atom(layer) do
    extras = Application.get_env(:anubis_mcp, :extra_client_transports, [])

    if layer in (@builtin_client_transports ++ @test_client_transports ++ extras) do
      :ok
    else
      {:error,
       "transport layer #{inspect(layer)} is not allowed. " <>
         "Built-in: #{inspect(@builtin_client_transports)}. " <>
         "Add custom ones via `config :anubis_mcp, :extra_client_transports, [#{inspect(layer)}]`."}
    end
  end

  def validate_client_transport(other) do
    {:error, "expected an atom transport layer, got: #{inspect(other)}"}
  end

  @doc """
  Validate that `layer` is an allowed server transport module.

  Mirrors `validate_client_transport/1`; opt in to extras via:

      config :anubis_mcp, :extra_server_transports, [MyApp.MyServerTransport]
  """
  def validate_server_transport(layer) when is_atom(layer) do
    extras = Application.get_env(:anubis_mcp, :extra_server_transports, [])

    if layer in (@builtin_server_transports ++ @test_server_transports ++ extras) do
      :ok
    else
      {:error,
       "transport layer #{inspect(layer)} is not allowed. " <>
         "Built-in: #{inspect(@builtin_server_transports)}. " <>
         "Add custom ones via `config :anubis_mcp, :extra_server_transports, [#{inspect(layer)}]`."}
    end
  end

  def validate_server_transport(other) do
    {:error, "expected an atom transport layer, got: #{inspect(other)}"}
  end

  defschema :process_name, {:either, {:pid, {:custom, &genserver_name/1}}}

  @doc "Checks if anubis should be compiled/used as standalone CLI or OTP library"
  def should_compile_cli? do
    Code.ensure_loaded?(Burrito) and
      Application.get_env(:anubis_mcp, :compile_cli?, false)
  end

  @doc """
  Validates a possible GenServer name using `peri` `:custom` type definition.
  """
  def genserver_name({:via, registry, _}) when is_atom(registry), do: :ok
  def genserver_name({:global, _}), do: :ok
  def genserver_name(name) when is_atom(name), do: :ok

  def genserver_name(val) do
    {:error, "#{inspect(val, pretty: true)} is not a valid name for a GenServer"}
  end

  @doc false
  def exported?(m, f, a) do
    function_exported?(m, f, a) or
      (Code.ensure_loaded?(m) and function_exported?(m, f, a))
  end

  @spec get_session_store_adapter :: nil | module
  def get_session_store_adapter do
    config = Application.get_env(:anubis_mcp, :session_store)
    enabled? = config[:enabled] || false
    adapter = config[:adapter]

    if enabled? && Code.ensure_loaded?(adapter), do: adapter
  end
end
