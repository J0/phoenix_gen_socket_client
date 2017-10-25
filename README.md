# phoenix_gen_socket_client

[![Build
Status](https://travis-ci.org/Aircloak/phoenix_gen_socket_client.svg?branch=master)](https://travis-ci.org/Aircloak/phoenix_gen_socket_client)
[![hex.pm](https://img.shields.io/hexpm/v/phoenix_gen_socket_client.svg?style=flat-square)](https://hex.pm/packages/phoenix_gen_socket_client)
[![hexdocs.pm](https://img.shields.io/badge/docs-latest-green.svg?style=flat-square)](https://hexdocs.pm/phoenix_gen_socket_client/)

This library implements an Elixir client for Phoenix Channels protocol 2.x. The client is implemented as a behaviour, which allows a lot of flexibility. For an alternative approach, you may also want to check [this project](https://github.com/mobileoverlord/phoenix_channel_client).

__NOTE__: From version 2.0 onwards this library only supports version 2.0 of the channels protocol (used on Phoenix 1.3 or later). If you need to use the version 1.0 of the protocol, you need to use [the older version of this library](https://hex.pm/packages/phoenix_gen_socket_client/1.2.0).


## Status

This library is continuously used in our system and it's been working for us, so we consider it to be stable :-)


## Prerequisites

You need to add the project as a dependency to your `mix.exs`:

```elixir

def project do
  [
    deps: [
      {:phoenix_gen_socket_client, "~> 2.0.0"}
      # ...
    ],
    # ...
  ]
end
```

You also need to add the transport (e.g. a websocket client), and serializer (e.g. JSON) as dependencies. Out of the box, the adapter for [sanmiguel/websocket_client](https://github.com/sanmiguel/websocket_client), and support for [devinus/poison](https://github.com/devinus/poison) is provided but you still need to include the libraries yourself:

```elixir
def project do
  [
    deps: [
      {:websocket_client, "~> 1.2"},
      {:poison, "~> 2.0"}

      # ...
    ],
    # ...
  ]
end
```


## Usage

This library is designed for flexibility, so the usage is a bit more involved. In general, you need to:

1. Implement a callback module for the `Phoenix.Channels.GenSocketClient` behaviour.
2. Start the socket process somewhere in your supervision tree.
3. Interact with the server from callback functions which are running in the socket process.

A simple demo is available [here](https://github.com/Aircloak/phoenix_gen_socket_client/tree/master/example). Here, we'll present some general ideas. For more details, refer to the [documentation](https://hexdocs.pm/phoenix_gen_socket_client/Phoenix.Channels.GenSocketClient.html).

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

If `init/1` returns `{:connect, url, query_params, initial_state}` the socket process will try to connect to the server. The connection is established in a separate process which we call the transport process. This process is the immediate child of the socket process. As a consequence, all communication takes place concurrently to the socket process. If you handle Erlang messages in the socket process you may need to keep track of whether you're connected or not.

The establishing of the connection is done asynchronously. The `handle_connected/2` callback is invoked after the connection is established. The `handle_disconnected/2` callback is invoked if establishing the connection fails or an existing connection is lost.

If the connection is not established (or dropped), you can reconnect from `handle_*` functions by returning `{:connect, state}` tuple. In this case the workflow is the same as when returning the `:connect` tuple from the `init/1` callback.

You may also decide to defer connecting to a later point in time by returning `{:noconnect, url, query_params, state}` from the `init/1` callback. To later establish a connection you need to send some message to the socket process, and handle that message in `handle_info` by returning the `{:connect, state}` tuple.

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
