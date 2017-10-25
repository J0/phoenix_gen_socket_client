defmodule Phoenix.Channels.GenSocketClient do
  @moduledoc """
  Communication with a Phoenix Channels server.

  This module powers a process which can connect to a Phoenix Channels server and
  exchange messages with it. Currently, only websocket communication protocol is
  supported.

  The module is implemented as a behaviour. To use it, you need to implement the
  callback module. Then, you can invoke `start_link/5` to start the socket process.
  The communication with the server is then controlled from that process.

  The connection is not automatically established during the creation. Instead,
  the implementation can return `{:connect, state}` to try to establish the
  connection. As the result either `handle_connected/2` or  `handle_disconnected/2`
  callbacks will be invoked.

  To join a topic, `join/3` function can be used. Depending on the result, either
  `handle_joined/4` or `handle_join_error/4` will be invoked. A client can join
  multiple topics on the same socket. It is also possible to leave a topic using
  the `leave/3` function.

  Once a client has joined a topic, it can use `push/4` to send messages to the
  server. If the server directly replies to the message, it will be handled in
  the `handle_reply/5` callback.

  If a server sends an independent message (i.e. the one which is not a direct
  reply), the `handle_message/5` callback will be invoked.

  If the server closes the channel, the `handle_channel_closed/4` will be invoked.
  This will not close the socket connection, and the client can continue to
  communicate on other channels, or attempt to rejoin the channel.

  ## Sending messages over the socket

  As mentioned, you can use `join/3`, `push/4`, and `leave/3` to send messages to
  the server. All of these functions require the `transport` information as the
  first argument. This information is available in most of the callback functions.

  Functions will return `{:ok, ref}` if the message was sent successfully,
  or `{:error, reason}`, where `ref` is the Phoenix ref used to uniquely identify
  a message on a channel.

  Error responses are returned in following situations:

  - The client is not connected
  - Attempt to send a message on a non-joined channel
  - Attempt to leave a non-joined channel
  - Attempt to join the already joined channel

  Keep in mind that there's no guarantee that a message will arrive to the server.
  You need to implement your own communication protocol on top of Phoenix
  Channels to obtain such guarantees.

  ## Process structure and lifecycle

  The behaviour will internally start the websocket client in a separate child
  process. This means that the communication runs concurrently to any processing
  which takes place in the behaviour.

  The socket process will crash only if the websocket process crashes, which can
  be caused only by some bug in the websocket client library. If you want to
  survive this situation, you can simply trap exits in the socket process, by
  calling `Process.flag(:trap_exit, true)` in the `init/1` callback. In this case,
  a crash of the websocket client process will be treated as a disconnect event.

  The socket process never decides to stop on its own. If you want to stop it,
  you can simply return `{:stop, reason, state}` from any of the callback.
  """
  use GenServer

  @type transport_opts :: any
  @type socket_opts :: [
    serializer: module,
    transport_opts: transport_opts
  ]
  @type callback_state :: any
  @opaque transport :: %{
    transport_mod: module,
    transport_pid: pid | nil,
    serializer: module
  }
  @type topic :: String.t
  @type event :: String.t
  @type payload :: %{String.t => any}
  @type out_payload :: %{(String.t | atom) => any}
  @type ref :: pos_integer
  @type message :: term
  @type encoded_message :: binary
  @type handler_response ::
    {:ok, callback_state} |
    {:connect, callback_state} |
    {:stop, reason::any, callback_state}
  @type query_params :: [{String.t, String.t}]

  @doc "Invoked when the process is created."
  @callback init(arg::any) ::
    {:connect, url::String.t, query_params, callback_state} |
    {:noconnect, url::String.t, query_params, callback_state} |
    :ignore |
    {:error, reason::any}


  # -------------------------------------------------------------------
  # Behaviour definition
  # -------------------------------------------------------------------

  @doc "Invoked after the client has successfully connected to the server."
  @callback handle_connected(transport, callback_state) :: handler_response

  @doc "Invoked after the client has been disconnected from the server."
  @callback handle_disconnected(reason::any, callback_state) :: handler_response

  @doc "Invoked after the client has successfully joined a topic."
  @callback handle_joined(topic, payload, transport, callback_state) :: handler_response

  @doc "Invoked if the server has refused a topic join request."
  @callback handle_join_error(topic, payload, transport, callback_state) :: handler_response

  @doc "Invoked after the server closes a channel."
  @callback handle_channel_closed(topic, payload, transport, callback_state) :: handler_response

  @doc "Invoked when a message from the server arrives."
  @callback handle_message(topic, event, payload, transport, callback_state) :: handler_response

  @doc "Invoked when the server replies to a message sent by the client."
  @callback handle_reply(topic, ref, payload, transport, callback_state) :: handler_response

  @doc "Invoked to handle an Erlang message."
  @callback handle_info(message::any, transport, callback_state) :: handler_response

  @doc "Invoked to handle a synchronous call."
  @callback handle_call(message::any, GenServer.from, transport, callback_state) ::
    {:reply, reply, new_state} |
    {:reply, reply, new_state, timeout | :hibernate} |
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason, reply, new_state} |
    {:stop, reason, new_state} when new_state: callback_state, reply: term, reason: term


  # -------------------------------------------------------------------
  # API functions
  # -------------------------------------------------------------------

  @doc "Starts the socket process."
  @spec start_link(callback::module, transport_mod::module, any, socket_opts, GenServer.options) ::
      GenServer.on_start
  def start_link(callback, transport_mod, arg, socket_opts \\ [], gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, {callback, transport_mod, arg, socket_opts}, gen_server_opts)
  end

  @doc "Makes a synchronous call to the server and waits for its reply."
  @spec call(GenServer.server, any, non_neg_integer) :: any
  def call(server, request, timeout \\ 5000), do:
    GenServer.call(server, {__MODULE__, :call, request}, timeout)

  @doc "Joins the topic."
  @spec join(transport, topic, out_payload) :: {:ok, ref} | {:error, reason::any}
  def join(transport, topic, payload \\ %{}),
    do: push(transport, topic, "phx_join", payload)

  @doc "Leaves the topic."
  @spec leave(transport, topic, out_payload) :: {:ok, ref} | {:error, reason::any}
  def leave(transport, topic, payload \\ %{}),
    do: push(transport, topic, "phx_leave", payload)

  @doc "Pushes a message to the topic."
  @spec push(transport, topic, event, out_payload) :: {:ok, ref} | {:error, reason::any}
  def push(%{transport_pid: nil}, _topic, _event, _payload), do: {:error, :disconnected}
  def push(transport, topic, event, payload) do
    cond do
      # first message on a channel must always be a join
      event != "phx_join" and join_ref(topic) == nil ->
        {:error, :not_joined}
      # join must always be a first message
      event == "phx_join" and join_ref(topic) != nil ->
        {:error, :already_joined}
      true ->
        {join_ref, ref} = next_ref(event, topic)
        case transport.serializer.encode_message([join_ref, ref, topic, event, payload]) do
          {:ok, encoded} ->
            transport.transport_mod.push(transport.transport_pid, encoded)
            {:ok, ref}
          {:error, error} -> {:error, {:encoding_error, error}}
        end
    end
  end

  @doc "Can be invoked to send a response to the client."
  @spec reply(GenServer.from, any) :: :ok
  defdelegate reply(from, response), to: GenServer


  # -------------------------------------------------------------------
  # API for transport (websocket client)
  # -------------------------------------------------------------------

  @doc "Notifies the socket process that the connection has been established."
  @spec notify_connected(GenServer.server) :: :ok
  def notify_connected(socket),
    do: GenServer.cast(socket, :notify_connected)

  @doc "Notifies the socket process about a disconnect."
  @spec notify_disconnected(GenServer.server, any) :: :ok
  def notify_disconnected(socket, reason),
    do: GenServer.cast(socket, {:notify_disconnected, reason})

  @doc "Forwards a received message to the socket process."
  @spec notify_message(GenServer.server, binary) :: :ok
  def notify_message(socket, message),
    do: GenServer.cast(socket, {:notify_message, message})


  # -------------------------------------------------------------------
  # GenServer callbacks
  # -------------------------------------------------------------------

  @doc false
  def init({callback, transport_mod, arg, socket_opts}) do
    case callback.init(arg) do
      {action, url, query_params, callback_state} when action in [:connect, :noconnect] ->
        {:ok,
          maybe_connect(action, %{
            url: url,
            query_params: Enum.uniq_by(query_params ++ [{"vsn", "2.0.0"}], &elem(&1, 0)),
            transport_mod: transport_mod,
            transport_opts: Keyword.get(socket_opts, :transport_opts, []),
            serializer: Keyword.get(socket_opts, :serializer, Phoenix.Channels.GenSocketClient.Serializer.Json),
            callback: callback,
            callback_state: callback_state,
            transport_pid: nil,
            transport_mref: nil,
          })
        }
      other -> other
    end
  end

  @doc false
  def handle_cast(:notify_connected, state) do
    invoke_callback(state, :handle_connected, [transport(state)])
  end
  def handle_cast({:notify_disconnected, reason}, state) do
    invoke_callback(reinit(state), :handle_disconnected, [reason])
  end
  def handle_cast({:notify_message, encoded_message}, state) do
    decoded_message = state.serializer.decode_message(encoded_message)
    handle_message(decoded_message, state)
  end

  @doc false
  def handle_call({__MODULE__, :call, request}, from, state) do
    case state.callback.handle_call(request, from, transport(state), state.callback_state) do
      {:reply, reply, callback_state} ->
        {:reply, reply, %{state | callback_state: callback_state}}
      {:reply, reply, callback_state, timeout} ->
        {:reply, reply, %{state | callback_state: callback_state}, timeout}
      {:noreply, callback_state} ->
        {:noreply, %{state | callback_state: callback_state}}
      {:noreply, callback_state, timeout} ->
        {:noreply, %{state | callback_state: callback_state}, timeout}
      {:stop, reason, callback_state} ->
        {:stop, reason, %{state | callback_state: callback_state}}
      {:stop, reason, reply, callback_state} ->
        {:stop, reason, reply, %{state | callback_state: callback_state}}
    end
  end

  @doc false
  def handle_info(
        {:DOWN, transport_mref, :process, _, reason},
        %{transport_mref: transport_mref} = state
      ) do
    invoke_callback(reinit(state), :handle_disconnected, [{:transport_down, reason}])
  end
  def handle_info(message, state) do
    invoke_callback(state, :handle_info, [message, transport(state)])
  end


  # -------------------------------------------------------------------
  # Handling of Phoenix messages
  # -------------------------------------------------------------------

  # server replied to a join message (recognized by ref 1 which is the first message on the topic)
  defp handle_message(message, state) do
    [join_ref, ref, topic, event, payload] = message
    cond do
      event == "phx_reply" and join_ref in [ref, nil] ->
        handle_join_reply(join_ref, topic, payload, state)
      join_ref != join_ref(topic) and event in ["phx_reply", "phx_close", "phx_error"] ->
        {:noreply, state}
      event == "phx_reply" ->
        handle_reply(ref, topic, payload, state)
      event in ["phx_close", "phx_error"] ->
        handle_channel_closed(topic, payload, state)
      true ->
        handle_server_message(topic, event, payload, state)
    end
  end

  defp handle_join_reply(join_ref, topic, payload, state) do
    case payload["status"] do
      "ok" ->
        store_join_ref(topic, join_ref)
        invoke_callback(state, :handle_joined, [topic, payload["response"], transport(state)])
      "error" ->
        invoke_callback(state, :handle_join_error, [topic, payload["response"], transport(state)])
    end
  end

  # server replied to a non-join message
  defp handle_reply(ref, topic, payload, state), do:
    invoke_callback(state, :handle_reply, [topic, ref, payload, transport(state)])

  # channel has been closed (phx_close) or crashed (phx_error) on the server
  defp handle_channel_closed(topic, payload, state) do
    delete_join_ref(topic)
    invoke_callback(state, :handle_channel_closed, [topic, payload, transport(state)])
  end

  defp handle_server_message(topic, event, payload, state), do:
    invoke_callback(state, :handle_message, [topic, event, payload, transport(state)])


  # -------------------------------------------------------------------
  # Internal functions
  # -------------------------------------------------------------------

  defp maybe_connect(:connect, state), do: connect(state)
  defp maybe_connect(:noconnect, state), do: state

  defp connect(%{transport_pid: nil} = state) do
    if params_in_url?(state.url), do:
      raise ArgumentError, "query parameters must be passed as a keyword list from the `init/1` callback"

    {:ok, transport_pid} = state.transport_mod.start_link(url(state), state.transport_opts)
    transport_mref = Process.monitor(transport_pid)
    %{state | transport_pid: transport_pid, transport_mref: transport_mref}
  end

  defp params_in_url?(url), do:
    not is_nil(URI.parse(url).query)

  defp url(state), do:
    "#{state.url}?#{URI.encode_query(state.query_params)}"

  defp reinit(state) do
    Process.get_keys()
    |> Enum.filter(&match?({__MODULE__, _}, &1))
    |> Enum.map(&Process.delete/1)

    if (state.transport_mref != nil), do: Process.demonitor(state.transport_mref, [:flush])
    %{state | transport_pid: nil, transport_mref: nil}
  end

  defp transport(state),
    do: Map.take(state, [:transport_mod, :transport_pid, :serializer])

  defp next_ref(event, topic) do
    ref = Process.get({__MODULE__, :ref}, 0) + 1
    Process.put({__MODULE__, :ref}, ref)

    join_ref = if event == "phx_join", do: ref, else: join_ref(topic)

    {join_ref, ref}
  end

  defp store_join_ref(topic, join_ref), do:
    Process.put({__MODULE__, {:join_ref, topic}}, join_ref)

  defp join_ref(topic), do:
    Process.get({__MODULE__, {:join_ref, topic}})

  defp delete_join_ref(topic), do:
    Process.delete({__MODULE__, {:join_ref, topic}})

  defp invoke_callback(state, function, args) do
    callback_response = apply(state.callback, function, args ++ [state.callback_state])
    handle_callback_response(callback_response, state)
  end

  defp handle_callback_response({:ok, callback_state}, state),
    do: {:noreply, %{state | callback_state: callback_state}}
  defp handle_callback_response({:connect, callback_state}, state),
    do: {:noreply, connect(%{state | callback_state: callback_state})}
  defp handle_callback_response({:stop, reason, callback_state}, state),
    do: {:stop, reason, %{state | callback_state: callback_state}}
end
