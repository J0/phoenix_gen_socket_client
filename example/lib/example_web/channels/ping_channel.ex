defmodule ExampleWeb.PingChannel do
  use Phoenix.Channel
  require Logger

  def join(_topic, _payload, socket) do
    Process.send_after(self(), :leave_or_crash, :rand.uniform(2000) + 2000)
    {:ok, socket}
  end

  def handle_info(:leave_or_crash, socket) do
    if :rand.uniform(5) == 1 do
      Logger.warn("deliberately disconnecting the client")
      Process.exit(socket.transport_pid, :kill)
      {:noreply, socket}
    else
      Logger.warn("deliberately leaving the topic")
      {:stop, :normal, socket}
    end
  end
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
  def handle_in(event, payload, socket) do
    Logger.warn("unhandled event #{event} #{inspect payload}")
    {:noreply, socket}
  end
end
