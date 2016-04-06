defmodule TestSite do
  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :aircloak_common

    socket "/test_socket", TestSite.Socket

    defoverridable start_link: 0
    def start_link do
      Application.put_env(:aircloak_common, __MODULE__, [
            https: false,
            http: [port: 29876],
            secret_key_base: String.duplicate("abcdefgh", 8),
            debug_errors: false,
            server: true,
            pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__]
          ])

      super()
    end
  end

  defmodule Socket do
    @moduledoc false
    use Phoenix.Socket

    transport :websocket, Phoenix.Transports.WebSocket

    # List of exposed channels
    channel "channel:*", TestSite.Channel

    def connect(params, socket) do
      case params["shared_secret"] do
        "supersecret" -> {:ok, socket}
        _ -> :error
      end
    end

    def id(_socket), do: ""
  end

  defmodule Channel do
    @moduledoc false
    use Phoenix.Channel

    def subscribe,
      do: :gproc.reg(subscriber_key())

    def join(topic, join_payload, socket) do
      notify({:join, topic, join_payload, self()})
      {:ok, socket}
    end

    def handle_info({:push, event, payload}, socket) do
      push(socket, event, payload)
      {:noreply, socket}
    end
    def handle_info({:stop, reason}, socket),
      do: {:stop, reason, socket}
    def handle_info({:crash, reason}, _socket),
      do: exit(reason)

    def handle_in("sync_event", payload, socket) do
      {:reply, {:ok, payload}, socket}
    end
    def handle_in(event, payload, socket) do
      notify({:handle_in, event, payload})
      {:noreply, socket}
    end

    def terminate(reason, _socket),
      do: notify({:terminate, reason})

    defp notify(message),
      do: :gproc.send(subscriber_key(), {__MODULE__, message})

    defp subscriber_key, do: {:p, :l, __MODULE__}
  end
end
