defmodule Channels.Client.Socket.Serializer do
  @moduledoc """
  Describes the serializer interface used in `Channels.Client.Socket` to encode/decode messages.
  """

  @doc "Invoked to decode the raw message."
  @callback decode_message(Socket.encoded_message) :: Socket.message

  @doc "Invoked to encode a socket message."
  @callback encode_message(Socket.message) :: {:text | :binary, Socket.encoded_message}
end

defmodule Channels.Client.Socket.Serializer.Json do
  @moduledoc "Json serializer for the socket client."
  @behaviour Channels.Client.Socket.Serializer


  # -------------------------------------------------------------------
  # Channels.Client.Socket.Serializer callbacks
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

defmodule Channels.Client.Socket.Serializer.GzipJson do
  @moduledoc "Gzip+Json serializer for the socket client."
  @behaviour Channels.Client.Socket.Serializer


  # -------------------------------------------------------------------
  # Channels.Client.Socket.Serializer callbacks
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
