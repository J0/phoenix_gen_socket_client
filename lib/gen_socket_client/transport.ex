defmodule Phoenix.Channels.GenSocketClient.Transport do
  @moduledoc """
  Transport contract used by `Phoenix.Channels.GenSocketClient`

  The implementation has following responsibilities:

  - Starts the transport process and links it to the caller. It is always assumed
    that the caller process is the socket process.
  - Pushes messages to the server when the `push/2` function is invoked.
  - Notifies the socket process about various events by invoking `notify_*`
    functions from the `Phoenix.Channels.GenSocketClient` module.
  """

  @type frame :: {:text | :binary, GenSocketClient.encoded_message}
  @type transport_pid :: pid

  @doc "Invoked from the socket process to start the transport process."
  @callback start_link(url::String.t, GenSocketClient.transport_opts) :: {:ok, transport_pid} | {:error, any}

  @doc "Invoked to push the frame."
  @callback push(transport_pid, frame) :: :ok
end
