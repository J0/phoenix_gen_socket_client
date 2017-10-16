defmodule Phoenix.Channels.GenSocketClient.Transport.WebSocketClient do
  @moduledoc """
  Websocket transport powered by the [websocket_client](https://github.com/sanmiguel/websocket_client)
  library.

  Supported transport options:

    - `keepalive` - Interval in which a ping message is sent to the server to keep the connection alive.
      By default, Phoenix server will timeout after 60 seconds of inactivity. By providing a keepalive value
      which is less than the server timeout, you can ensure that the connection remains open, even if  no
      messages are being passed between the client and the server. If you don't want to disable this mechanism,
      you can pass `nil`. If this option is not provided, the default value of 30 seconds is used.
  """
  @behaviour Phoenix.Channels.GenSocketClient.Transport
  @behaviour :websocket_client

  require Logger
  require Record
  alias Phoenix.Channels.GenSocketClient


  # -------------------------------------------------------------------
  # Phoenix.Channels.GenSocketClient.Transport callbacks
  # -------------------------------------------------------------------

  @doc false
  def start_link(url, transport_options) do
    url
    |> to_charlist()
    |> :websocket_client.start_link(__MODULE__, [self(), transport_options])
  end

  @doc false
  def push(pid, frame) do
    send(pid, {:send_frame, frame})
    :ok
  end


  # -------------------------------------------------------------------
  # :websocket_client callbacks
  # -------------------------------------------------------------------

  @doc false
  def init([socket, transport_options]) do
    {:once, %{socket: socket, keepalive: Keyword.get(transport_options, :keepalive, :timer.seconds(30))}}
  end

  @doc false
  def onconnect(_req, state) do
    GenSocketClient.notify_connected(state.socket)
    case state.keepalive do
      nil -> {:ok, state}
      keepalive -> {:ok, state, keepalive}
    end
  end

  @doc false
  def websocket_handle({:pong, _message}, _req, state),
    do: {:ok, state}
  def websocket_handle({type, message}, _req, state) when type in [:text, :binary] do
    GenSocketClient.notify_message(state.socket, message)
    {:ok, state}
  end
  def websocket_handle(other_msg, _req, state) do
    Logger.warn(fn -> "Unknown message #{inspect other_msg}" end)
    {:ok, state}
  end

  @doc false
  def websocket_info({:send_frame, frame}, _req, state),
    do: {:reply, frame, state}
  def websocket_info(_message, _req, state),
    do: {:ok, state}

  @doc false
  def ondisconnect(reason, state) do
    GenSocketClient.notify_disconnected(state.socket, reason)
    {:close, :normal, state}
  end

  @doc false
  def websocket_terminate(_reason, _req, _state), do: :ok
end
