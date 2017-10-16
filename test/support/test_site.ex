defmodule TestSite do
  defmodule PubSub do
    def start_link(), do:
      Registry.start_link(:duplicate, __MODULE__)

    def subscribe(subscriber_key), do:
      Registry.register(__MODULE__, subscriber_key, nil)

    def notify(subscriber_key, message), do:
      __MODULE__
      |> Registry.lookup(subscriber_key)
      |> Enum.map(fn({pid, _value}) -> pid end)
      |> Enum.each(&send(&1, message))
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_gen_socket_client

    socket "/test_socket", TestSite.Socket

    @doc false
    def init(:supervisor, config) do
      {:ok,
        Keyword.merge(config,
          https: false,
          http: [port: 29876],
          secret_key_base: String.duplicate("abcdefgh", 8),
          debug_errors: false,
          server: true,
          pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__]
        )
      }
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

    def subscribe(), do:
      TestSite.PubSub.subscribe(__MODULE__)

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

    def terminate(reason, _socket), do:
      notify({:terminate, reason})

    defp notify(message), do:
      TestSite.PubSub.notify(__MODULE__, {__MODULE__, message})
  end
end
