defmodule Phoenix.Channels.GenSocketClient.Serializer do
  @moduledoc """
  Describes the serializer interface used in `Phoenix.Channels.GenSocketClient` to encode/decode messages.
  """

  alias Phoenix.Channels.GenSocketClient

  @doc "Invoked to decode the raw message."
  @callback decode_message(GenSocketClient.encoded_message) :: GenSocketClient.message

  @doc "Invoked to encode a socket message."
  @callback encode_message(GenSocketClient.message) :: Phoenix.Channels.GenSocketClient.Transport.frame
end

defmodule Phoenix.Channels.GenSocketClient.Serializer.Json do
  @moduledoc "Json serializer for the socket client."
  @behaviour Phoenix.Channels.GenSocketClient.Serializer


  # -------------------------------------------------------------------
  # Phoenix.Channels.GenSocketClient.Serializer callbacks
  # -------------------------------------------------------------------

  @doc false
  def decode_message(encoded_message) do
    %{"topic" => topic, "event" => event, "payload" => payload, "ref" => ref} =
      Poison.decode!(encoded_message)

    %{topic: topic, event: event, payload: payload, ref: ref}
  end

  @doc false
  def encode_message(message) do
    {:binary, Poison.encode!(message)}
  end
end

defmodule Phoenix.Channels.GenSocketClient.Serializer.GzipJson do
  @moduledoc "Gzip+Json serializer for the socket client."
  @behaviour Phoenix.Channels.GenSocketClient.Serializer


  # -------------------------------------------------------------------
  # Phoenix.Channels.GenSocketClient.Serializer callbacks
  # -------------------------------------------------------------------

  @doc false
  def decode_message(encoded_message) do
    %{"topic" => topic, "event" => event, "payload" => payload, "ref" => ref} =
      encoded_message
      |> :zlib.gunzip()
      |> Poison.decode!()

    %{topic: topic, event: event, payload: payload, ref: ref}
  end

  @doc false
  def encode_message(message) do
    {:binary, message |> Poison.encode_to_iodata!() |> :zlib.gzip}
  end
end
