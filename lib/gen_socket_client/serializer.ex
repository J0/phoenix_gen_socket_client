defmodule Phoenix.Channels.GenSocketClient.Serializer do
  @moduledoc """
  Describes the serializer interface used in `Phoenix.Channels.GenSocketClient` to encode/decode messages.
  """

  alias Phoenix.Channels.GenSocketClient

  @doc "Invoked to decode the raw message."
  @callback decode_message(GenSocketClient.encoded_message) :: GenSocketClient.message

  @doc "Invoked to encode a socket message."
  @callback encode_message(GenSocketClient.message) ::
    {:ok, Phoenix.Channels.GenSocketClient.Transport.frame} | {:error, reason :: any}
end

defmodule Phoenix.Channels.GenSocketClient.Serializer.Json do
  @moduledoc "Json serializer for the socket client."
  @behaviour Phoenix.Channels.GenSocketClient.Serializer


  # -------------------------------------------------------------------
  # Phoenix.Channels.GenSocketClient.Serializer callbacks
  # -------------------------------------------------------------------

  @doc false
  def decode_message(encoded_message), do:
    Poison.decode!(encoded_message)

  @doc false
  def encode_message(message) do
    case Poison.encode(message) do
      {:ok, encoded} -> {:ok, {:binary, encoded}}
      error -> error
    end
  end
end

defmodule Phoenix.Channels.GenSocketClient.Serializer.GzipJson do
  @moduledoc "Gzip+Json serializer for the socket client."
  @behaviour Phoenix.Channels.GenSocketClient.Serializer


  # -------------------------------------------------------------------
  # Phoenix.Channels.GenSocketClient.Serializer callbacks
  # -------------------------------------------------------------------

  @doc false
  def decode_message(encoded_message), do:
    encoded_message
    |> :zlib.gunzip()
    |> Poison.decode!()

  @doc false
  def encode_message(message) do
    case Poison.encode_to_iodata(message) do
      {:ok, encoded} -> {:ok, {:binary, :zlib.gzip(encoded)}}
      error -> error
    end
  end
end
