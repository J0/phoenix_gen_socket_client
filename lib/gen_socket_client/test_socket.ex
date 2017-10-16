defmodule Phoenix.Channels.GenSocketClient.TestSocket do
  @moduledoc """
  A simple synchronous Phoenix Channels client.

  This module can be used in your project for testing your own functionality. The
  module implements the `Phoenix.Channels.GenSocketClient` behaviour to provide
  a controllable API for channel clients. The implementation is very basic,
  and is useful for tests only. It's not advised to use this module in
  production, because there are various edge cases which can cause subtle
  bugs. You're instead advised to implement your own callback for the
  `Phoenix.Channels.GenSocketClient` behaviour.
  """
  alias Phoenix.Channels.GenSocketClient
  @behaviour GenSocketClient


  # -------------------------------------------------------------------
  # API functions
  # -------------------------------------------------------------------

  @doc "Starts the driver process."
  @spec start_link(module, String.t, GenSocketClient.query_params, boolean, GenSocketClient.socket_opts) ::
    GenServer.on_start
  def start_link(transport, url, query_params, connect \\ true, socket_opts \\ []),
    do: GenSocketClient.start_link(__MODULE__, transport, {url, query_params, connect, self()}, socket_opts)

  @doc "Connect to the server."
  @spec connect(GenServer.server) :: :ok
  def connect(socket) do
    send(socket, :connect)
    :ok
  end

  @doc "Waits until the socket is connected or disconnected"
  @spec wait_connect_status(GenServer.server, GenServer.timeout) ::
      :connected |
      {:disconnected, any} |
      {:error, :timeout}
  def wait_connect_status(socket, timeout \\ :timer.seconds(5)) do
    receive do
      {^socket, :connected} -> :connected
      {^socket, :disconnected, {:error, reason}} -> {:disconnected, reason}
      {^socket, :disconnected, reason} -> {:disconnected, reason}
    after timeout ->
      {:error, :timeout}
    end
  end

  @doc "Joins a topic on the connected socket."
  @spec join(GenServer.server, GenSocketClient.topic, GenSocketClient.payload, GenServer.timeout) ::
    {:ok, {GenSocketClient.topic, GenSocketClient.payload}} |
    {:error, any}
  def join(socket, topic, payload \\ %{}, timeout \\ 5000) do
    send(socket, {:join, topic, payload})

    receive do
      {^socket, :join_ok, result} -> {:ok, result}
      {^socket, :join_error, reason} -> {:error, reason}
    after timeout ->
      {:error, :timeout}
    end
  end

  @doc "Leaves the topic."
  @spec leave(GenServer.server, GenSocketClient.topic, GenSocketClient.payload, GenServer.timeout) ::
    {:ok, GenSocketClient.payload} |
    {:error, any}
  def leave(socket, topic, payload \\ %{}, timeout \\ 5000) do
    send(socket, {:leave, topic, payload})

    receive do
      {^socket, :leave_ref, _ref} ->
        receive do
          {^socket, :channel_closed, ^topic, payload} -> {:ok, payload}
        after timeout ->
          {:error, :timeout}
        end
      {^socket, :leave_error, reason} ->
        {:error, reason}
    after timeout ->
      {:error, :timeout}
    end
  end

  @doc "Pushes a message to the topic."
  @spec push(GenServer.server, GenSocketClient.topic, GenSocketClient.event, GenSocketClient.payload,
      GenServer.timeout) ::
    {:ok, GenSocketClient.ref} |
    {:error, any}
  def push(socket, topic, event, payload \\ %{}, timeout \\ 5000) do
    GenSocketClient.call(socket, {:push, topic, event, payload}, timeout)
  end

  @doc "Pushes a message to the topic and awaits the direct response from the server."
  @spec push_sync(GenServer.server, GenSocketClient.topic, GenSocketClient.event, GenSocketClient.payload,
      GenServer.timeout) ::
    {:ok, GenSocketClient.payload} |
    {:error, any}
  def push_sync(socket, topic, event, payload \\ %{}, timeout \\ 5000) do
    with {:ok, ref} <- push(socket, topic, event, payload, timeout) do
      receive do
        {^socket, :reply, ^topic, ^ref, result} -> {:ok, result}
      after timeout ->
        {:error, :timeout}
      end
    end
  end

  @doc "Awaits a message from the socket."
  @spec await_message(GenServer.server, GenServer.timeout) ::
    {:ok, GenSocketClient.topic, GenSocketClient.event, GenSocketClient.payload} | {:error, :timeout}
  def await_message(socket, timeout \\ 5000) do
    receive do
      {^socket, :message, message} -> {:ok, message}
    after timeout ->
      {:error, :timeout}
    end
  end


  # -------------------------------------------------------------------
  # Channels.Client.GenSocketClient callbacks
  # -------------------------------------------------------------------

  @doc false
  def init({url, query_params, true, client}), do: {:connect, url, query_params, client}
  def init({url, query_params, false, client}), do: {:noconnect, url, query_params, client}

  @doc false
  def handle_connected(_transport, client) do
    send(client, {self(), :connected})
    {:ok, client}
  end

  @doc false
  def handle_disconnected(reason, client) do
    send(client, {self(), :disconnected, reason})
    {:ok, client}
  end

  @doc false
  def handle_joined(topic, payload, _transport, client) do
    send(client, {self(), :join_ok, {topic, payload}})
    {:ok, client}
  end

  @doc false
  def handle_join_error(topic, payload, _transport, client) do
    send(client, {self(), :join_error, {:server_rejected, topic, payload}})
    {:ok, client}
  end

  @doc false
  def handle_channel_closed(topic, payload, _transport, client) do
    send(client, {self(), :channel_closed, topic, payload})
    {:ok, client}
  end

  @doc false
  def handle_message(topic, event, payload, _transport, client) do
    send(client, {self(), :message, {topic, event, payload}})
    {:ok, client}
  end

  @doc false
  def handle_reply(topic, ref, payload, _transport, client) do
    send(client, {self(), :reply, topic, ref, payload})
    {:ok, client}
  end

  @doc false
  def handle_info(:connect, _transport, client),
    do: {:connect, client}
  def handle_info({:join, topic, payload}, transport, client) do
    case GenSocketClient.join(transport, topic, payload) do
      {:error, reason} -> send(client, {self(), :join_error, reason})
      {:ok, _ref} -> :ok
    end

    {:ok, client}
  end
  def handle_info({:leave, topic, payload}, transport, client) do
    case GenSocketClient.leave(transport, topic, payload) do
      {:error, reason} -> send(client, {self(), :leave_error, reason})
      {:ok, ref} -> send(client, {self(), :leave_ref, ref})
    end
    {:ok, client}
  end

  @doc false
  def handle_call({:push, topic, event, payload}, _from, transport, client) do
    push_result = GenSocketClient.push(transport, topic, event, payload)
    {:reply, push_result, client}
  end
end
