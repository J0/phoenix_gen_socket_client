defmodule Channels.Client.TestSocket do
  @moduledoc """
  A simple synchronous Phoenix Channels client.

  This module implements the `Channels.Client.Socket` behaviour to provide
  a controllable API for channel clients. The implementation is very basic,
  and is useful for tests only. It's not advised to use this module in
  production, because there are various edge cases which can cause subtle
  bugs. You're instead advised to implement your own callback for the
  `Channels.Client.Socket` behaviour.

  Notice that the module is defined in the lib (and not in the test), which
  allows us to reuse it in tests of other projects (such as air).
  """
  alias Channels.Client.Socket
  @behaviour Socket


  # -------------------------------------------------------------------
  # API functions
  # -------------------------------------------------------------------

  @doc "Starts the driver process."
  @spec start_link(String.t, Socket.socket_opts) :: GenServer.on_start
  def start_link(url, socket_opts \\ []),
    do: Socket.start_link(__MODULE__, {url, self}, socket_opts)

  @doc "Connect to the server."
  @spec connect(GenServer.server, GenServer.timeout) :: :ok | {:error, any}
  def connect(socket, timeout \\ :timer.seconds(5)) do
    send(socket, :connect)

    receive do
      {^socket, :connected} -> :ok
      {^socket, :disconnected, {:error, reason}} -> {:error, reason}
      {^socket, :disconnected, reason} -> {:error, reason}
    after timeout ->
      {:error, :timeout}
    end
  end

  @doc "Joins a topic on the connected socket."
  @spec join(GenServer.server, Socket.topic, Socket.payload, GenServer.timeout) ::
    {:ok, {Socket.topic, Socket.payload}} |
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
  @spec leave(GenServer.server, Socket.topic, Socket.payload, GenServer.timeout) ::
    {:ok, Socket.payload} |
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
  @spec push(GenServer.server, Socket.topic, Socket.event, Socket.payload, GenServer.timeout) ::
    {:ok, Socket.ref} |
    {:error, any}
  def push(socket, topic, event, payload \\ %{}, timeout \\ 5000) do
    send(socket, {:push, topic, event, payload})

    receive do
      {^socket, :push_result, result} -> result
    after timeout ->
      {:error, :timeout}
    end
  end

  @doc "Pushes a message to the topic and awaits the direct response from the server."
  @spec push_sync(GenServer.server, Socket.topic, Socket.event, Socket.payload, GenServer.timeout) ::
    {:ok, Socket.payload} |
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
    {:ok, Socket.topic, Socket.event, Socket.payload} | {:error, :timeout}
  def await_message(socket, timeout \\ 5000) do
    receive do
      {^socket, :message, message} -> {:ok, message}
    after timeout ->
      {:error, :timeout}
    end
  end


  # -------------------------------------------------------------------
  # Channels.Client.Socket callbacks
  # -------------------------------------------------------------------

  @doc false
  def init({url, client}),
    do: {:ok, url, client}

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
    case Socket.join(transport, topic, payload) do
      {:error, reason} -> send(client, {self(), :join_error, reason})
      {:ok, _ref} -> :ok
    end

    {:ok, client}
  end
  def handle_info({:leave, topic, payload}, transport, client) do
    case Socket.leave(transport, topic, payload) do
      {:error, reason} -> send(client, {self(), :leave_error, reason})
      {:ok, ref} -> send(client, {self(), :leave_ref, ref})
    end
    {:ok, client}
  end
  def handle_info({:push, topic, event, payload}, transport, client) do
    push_result = Socket.push(transport, topic, event, payload)
    send(client, {self(), :push_result, push_result})
    {:ok, client}
  end
end
