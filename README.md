# phoenix_gen_socket_client

[![Build
Status](https://travis-ci.org/Aircloak/phoenix_gen_socket_client.svg?branch=master)](https://travis-ci.org/Aircloak/phoenix_gen_socket_client)

This library implements an Elixir client for Phoenix Channels protocol. The client is implemented as a behaviour, which allows a lot of flexibility. For an alternative approach, you may also want to check [this project](https://github.com/mobileoverlord/phoenix_channel_client).


## Status

This library is in a very early alpha, so it's highly unstable and untested. Breaking changes are very likely. Use at your own peril :-)


## Prerequisites

You need to add the project as a dependency to your `mix.exs`:

```elixir

def project do
  [
    deps: [
      {:phoenix_gen_socket_client, github: "aircloak/phoenix_gen_socket_client"}
      # ...
    ],
    application: [
      applications: [:phoenix_gen_socket_client, # ...],
      # ...
    ]
  ]
end
```

You also need to add the transport (e.g. a websocket client), and serializer (e.g. JSON) as dependencies. Out of the box, the adapter for [sanmiguel/websocket_client](https://github.com/sanmiguel/websocket_client), and support for [devinus/poison](https://github.com/devinus/poison) is provided but you still need to include the libraries yourself:

```elixir
def project do
  [
    deps: [
      {:websocket_client, github: "sanmiguel/websocket_client", tag: "1.1.0"},
      {:poison, "~> 1.5.2"}

      # ...
    ],
    application: [
      applications: [:websocket_client, # ...],
      # ...
    ]
  ]
end
```


## Usage

This library is designed for flexibility, so the usage is a bit more involved. In general, you need to:

1. Implement a callback module for the `Phoenix.Channels.GenSocketClient` behaviour.
2. Start the socket process somewhere in your supervision tree.
3. Interact with the server from callback functions which are running in the socket process.

A simple demo is available in the [example](example) folder. Here, we'll present some general ideas. For more details, refer to the documentation. It is currently not available online, but you can clone this repo and build it locally with `MIX_ENV=docs mix docs`.

__Note__: In the subsequent code snippets we assume that `Phoenix.Channels.GenSocketClient` is aliased, so we use `GenSocketClient`.


### Starting the socket process

Starting the process works similar to other behaviours, such as `GenServer`:

```elixir
GenSocketClient.start_link(
  callback_module,
  transport_module,
  arbitrary_argument,
  socket_opts, # defaults to []
  gen_server_opts # defaults to []
)
```

For `transport_module` you can pass any module which implements the `Phoenix.Channels.GenSocketClient.Transport` behaviour. Out of the box, you have the module `Phoenix.Channels.GenSocketClient.Transport.WebSocketClient` available.

The code above will start another process where the `init/1` function of the `callback_module` is invoked. This function needs to provide the initial state and the socket url. The tuple also determines whether the connection will be immediately established or not.

The socket url must also include the transport suffix. For example, if in the server socket you have declared socket with `socket "/my_socket", ...`, then the url for the websocket transport would be `ws://server_url/my_socket/websocket`.


### Connection life-cycle

If `init/1` returns `{:connect, url, initial_state}`, the connection will be established immediately. The connection is established in a separate process, which we call the _transport process_. This process is the immediate child of the socket process. Consequently, all communication takes place concurrently to the socket process. If you handle some Erlang messages in the socket process, you may need to keep track of whether you're connected or not.

If the connection is established, the `handle_connected/2` callback will be invoked. If establishing of the connection fails, `handle_disconnected/2` callback is invoked. The same callback is invoked if the established connection is lost.

If the connection is not established (or dropped), you can reconnect from `handle_*` functions by returning `{:connect, state}` tuple.

Finally, you can also decide to connect at some later time by returning `{:noconnect, url, state}` from the `init/1` callback. To connect later, you need to send an Erlang message to the socket process, and return `{:connect, state}` tuple.

Though somewhat elaborate, this approach has following benefits:

1. The socket process starts immediately without waiting for the connection to be established.
2. The socket process can live in the supervision tree even if the connection is not established.
3. Implementing reconnection logic is very flexible. You can trigger a reconnect directly from `handle_disconnected/2`, or send yourself a delayed message. You can also easily accumulate outgoing messages until you reconnect, or you can attempt a finite number of reconnects and then give up.


### Sending messages over a socket

Once you're connected to the socket, you can issue messages. Most `handle_*` callbacks receive a `transport` argument. You can pass this argument to functions such as `GenSocketClient.join/3`, `GenSocketClient.leave/3`, `GenSocketClient.push/4` to send messages over a connected socket. If you're disconnected when calling these functions, they will return an error. Otherwise they return a successful response.

Of course, there's no guarantees that the message has arrived to the server, since a netsplit can happen at any point in time.


### Channel life-cycle

To join a topic, you can use `GenSocketClient.join/3`. Depending on the outcome, `handle_joined/4` or `handle_join_error/4` callback is invoked. If the server leaves the channel at some later point, `handle_channel_closed/4` callback will be invoked. Just like with socket connections, this gives you a lot of flexibility if you want to implement the rejoin logic. On socket disconnect, all channels are closed, but `handle_channel_closed/4` is not invoked.

You can of course join multiple topics on the same socket. Unlike in Phoenix, all messages are handled in the socket process. Besides the socket and the transport process, there are no additional processes created. Such decisions are deliberately left out of the `GenSocketClient` to support more flexibility.


### Communicating on a channel

To send a message on the connected channel, you can use `GenSocketClient.push/4`. If the socket has not joined the topic, an error is returned. On success, the message reference (aka _ref_) is returned.

If the server-side channel replies directly (using the `{:reply, ...}`), the `handle_reply/5` callback is invoked with the matching ref. Refs are unique only per channel-session. Two channels can use the same refs. Also, refs can be reused after you rejoin a topic.

If the server sends an asynchronous message (i.e. not a direct reply), the `handle_message/5` callback is invoked.


## Copyright and License

Copyright (c) 2016 Aircloak

The source code is licensed under the [MIT License](./LICENSE.md).
