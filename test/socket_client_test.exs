defmodule Phoenix.Channels.GenSocketClientTest do
  use ExUnit.Case, async: false

  alias TestSite.Endpoint
  alias Phoenix.Channels.GenSocketClient.TestSocket

  setup_all do
    ExUnit.CaptureLog.capture_log(fn -> Endpoint.start_link() end)
    :ok
  end

  setup do
    TestSite.Channel.subscribe()
    :ok
  end

  test "connection success" do
    assert {:ok, socket} = start_socket()
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:ok, {"channel:1", %{}}} == TestSocket.join(socket, "channel:1")
  end

  test "no auto connect" do
    assert {:ok, socket} = start_socket(url(), false)
    refute :connected == TestSocket.wait_connect_status(socket, 100)
    TestSocket.connect(socket)
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:ok, {"channel:1", %{}}} == TestSocket.join(socket, "channel:1")
  end

  test "client message push" do
    assert {:ok, socket} = start_socket()
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:ok, {"channel:1", %{}}} == TestSocket.join(socket, "channel:1", %{"foo" => "bar"})
    assert {:ok, _ref} = TestSocket.push(socket, "channel:1", "some_event", %{"foo" => "bar"})
    assert_receive {TestSite.Channel, {:handle_in, "some_event", %{"foo" => "bar"}}}
  end

  test "send and response" do
    conn = join_channel()
    {:ok, payload} = TestSocket.push_sync(conn.socket, "channel:1", "sync_event", %{"foo" => "bar"})
    assert %{"status" => "ok", "response" => %{"foo" => "bar"}} = payload
  end

  test "client message receive" do
    conn = join_channel()
    send(conn.server_channel, {:push, "some_event", %{"foo" => "bar"}})
    assert {:ok, {"channel:1", "some_event", %{"foo" => "bar"}}} = TestSocket.await_message(conn.socket)
  end

  test "leave the channel" do
    conn = join_channel()
    assert {:ok, %{}} == TestSocket.leave(conn.socket, "channel:1")
    assert_receive {TestSite.Channel, {:terminate, {:shutdown, :left}}}
  end

  test "client message push references" do
    conn = join_channel()
    assert {:ok, _} = TestSocket.join(conn.socket, "channel:2")

    assert {:ok, 2} == TestSocket.push(conn.socket, "channel:1", "some_event")
    assert {:ok, 3} == TestSocket.push(conn.socket, "channel:1", "another_event")
    assert {:ok, 2} == TestSocket.push(conn.socket, "channel:2", "channel_2_event")
    assert {:ok, 4} == TestSocket.push(conn.socket, "channel:1", "yet_another_event")

    # leave and rejoin the channel, and verify that counter has been reset
    assert {:ok, %{}} == TestSocket.leave(conn.socket, "channel:1")
    TestSocket.join(conn.socket, "channel:1")
    assert {:ok, 2} == TestSocket.push(conn.socket, "channel:1", "some_event")

    # the other channel counter should not be reset
    assert {:ok, 3} == TestSocket.push(conn.socket, "channel:2", "channel_2_second_event")
  end

  test "connection error" do
    assert {:ok, socket} = start_socket("ws://127.0.0.1:29877")
    assert {:disconnected, :econnrefused} == TestSocket.wait_connect_status(socket)
  end

  test "connection refused by socket" do
    assert {:ok, socket} = start_socket(url(%{shared_secret: "invalid_secret"}))
    assert {:disconnected, {403, "Forbidden"}} == TestSocket.wait_connect_status(socket)
  end

  test "transport process terminates" do
    assert {:ok, socket} = start_socket()
    assert :connected == TestSocket.wait_connect_status(socket)
    transport_pid = :sys.get_state(socket).transport_pid
    GenServer.stop(transport_pid)
    assert {:disconnected, {:transport_down, :normal}} == TestSocket.wait_connect_status(socket)

    # verify that we can reconnect and use the socket
    TestSocket.connect(socket)
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:ok, {"channel:1", _}} = TestSocket.join(socket, "channel:1")
  end

  test "can't interact when disconnected" do
    assert {:ok, socket} = start_socket()
    transport_pid = :sys.get_state(socket).transport_pid
    GenServer.stop(transport_pid)
    assert {:disconnected, _} = TestSocket.wait_connect_status(socket)
    assert {:error, :disconnected} = TestSocket.join(socket, "channel:1")
    assert {:error, :disconnected} = TestSocket.leave(socket, "channel:1")
    assert {:error, :disconnected} = TestSocket.push(socket, "channel:1", "some_event")
    assert {:error, :disconnected} = TestSocket.push_sync(socket, "channel:1", "some_event")
  end

  test "refused channel join" do
    assert {:ok, socket} = start_socket()
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:error, reason} = TestSocket.join(socket, "invalid_channel")
    assert {:server_rejected, "invalid_channel", %{"reason" => "unmatched topic"}} == reason
  end

  test "double join" do
    conn = join_channel()
    TestSocket.join(conn.socket, "channel:1")
    assert {:error, :already_joined} == TestSocket.join(conn.socket, "channel:1")
  end

  test "no push before join" do
    assert {:ok, socket} = start_socket()
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:error, :not_joined} == TestSocket.push(socket, "channel:1", "some_event")

    # Verify that we can still join after the invalid push
    assert {:ok, {"channel:1", _}} = TestSocket.join(socket, "channel:1")
    assert {:ok, _} = TestSocket.push(socket, "channel:1", "some_event")
  end

  test "server channel disconnects" do
    conn = join_channel()
    socket = conn.socket
    send(conn.server_channel, {:stop, :shutdown})
    assert_receive {^socket, :channel_closed, "channel:1", %{}}
  end

  test "server channel crashes" do
    conn = join_channel()
    socket = conn.socket
    ExUnit.CaptureLog.capture_log(fn ->
          send(conn.server_channel, {:crash, :some_reason})
          assert_receive {^socket, :channel_closed, "channel:1", %{}}
        end)
  end

  defp join_channel do
    assert {:ok, socket} = start_socket()
    assert :connected == TestSocket.wait_connect_status(socket)
    assert {:ok, {"channel:1", %{}}} == TestSocket.join(socket, "channel:1")
    assert_receive {TestSite.Channel, {:join, "channel:1", _, server_channel}}

    %{socket: socket, server_channel: server_channel}
  end

  defp start_socket(url \\ url(), connect \\ true) do
    TestSocket.start_link(Phoenix.Channels.GenSocketClient.Transport.WebSocketClient, url, connect)
  end

  defp url(params \\ %{shared_secret: "supersecret"}) do
    "#{Endpoint.url()}/test_socket/websocket?#{URI.encode_query(params)}"
    |> String.replace(~r(http://), "ws://")
    |> String.replace(~r(https://), "wss://")
  end
end
