## 3.2.2

This library has been retired.
It is no longer maintained.
It will not receive security fixes or updates.

For more information, please read this issue:
https://github.com/Aircloak/phoenix_gen_socket_client/issues/57


## 3.2.1

- Fixed text encoding bug when upgrading Phoenix to 1.5.7 (issue #54). Thanks @vladra

## 3.2.0

- Allow passing `:extra_headers` and `:ssl_verify` options to websocket_client. Thanks @albertored

## 3.1.0

- Fix timeout typespec in GenSocketClient call function. Thanks @matt-mazzucato
- Add support for optional terminate callback

## 3.0.0

- The provided Json serializer uses Jason rather than Poison. This is a breaking change and the cause of the major version bump.
- Minor fixes to doc and tests
- Tests against more recent Elixir (1.10) and Erlang (22) versions
- Dropping support for Elixir versions prior to 1.8 and Erlang prior to 22.

## 2.1.1

- Uses credo only in `:dev` and `:test`, so it's not treated as a transitive dependency in client projects.

## 2.1.0

- Added `Phoenix.Channels.GenSocketClient.joined?/1`
- Added support for changing url and/or query parameters when reconnecting

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
