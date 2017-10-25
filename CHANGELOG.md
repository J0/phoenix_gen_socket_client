## 2.0.0

- requires Elixir 1.5 or greater
- supports only Phoenix channels protocol 2.0 (so the library works only with Phoenix 1.3+ on sockets which are powered by 2.0 serializers)
- takes URL parameters separately (see spec for `Phoenix.Channels.GenSocketClient.init/1` and `Phoenix.Channels.GenSocketClient.TestSocket.start_link/1`)
- properly enforces optional dependencies (Poison and websocket_client)

## 1.2.0

- Serialization failures are propagated as tuples instead of exceptions

## 1.1.1

- Changed the internals to simplify creating a large number of open connections.

## 1.1.0

- Added `call/3` to support synchronous calls to the socket process.
- The behavior now mandates the `handle_call/4` callback function.
