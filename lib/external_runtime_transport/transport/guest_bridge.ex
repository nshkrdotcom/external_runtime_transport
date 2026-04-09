defmodule ExternalRuntimeTransport.Transport.GuestBridge do
  @moduledoc false

  alias ExecutionPlane.Process.Transport.GuestBridge, as: RuntimeGuestBridge
  alias ExternalRuntimeTransport.{Command, Transport}
  alias ExternalRuntimeTransport.ExecutionSurface.Adapter
  alias ExternalRuntimeTransport.ExecutionSurface.Capabilities

  @behaviour Adapter
  @behaviour Transport

  @surface_kind :guest_bridge

  @impl Adapter
  def surface_kind, do: @surface_kind

  @impl Adapter
  def capabilities do
    RuntimeGuestBridge.capabilities()
    |> Map.from_struct()
    |> Capabilities.new!()
  end

  @impl Adapter
  defdelegate normalize_transport_options(options), to: RuntimeGuestBridge

  @impl Transport
  def start(opts) when is_list(opts),
    do: Transport.start(Keyword.put(opts, :surface_kind, @surface_kind))

  @impl Transport
  def start_link(opts) when is_list(opts),
    do: Transport.start_link(Keyword.put(opts, :surface_kind, @surface_kind))

  @impl Transport
  def run(%Command{} = command, opts) when is_list(opts),
    do: Transport.run(command, Keyword.put(opts, :surface_kind, @surface_kind))

  @impl Transport
  defdelegate send(transport, message), to: Transport

  @impl Transport
  defdelegate subscribe(transport, pid), to: Transport

  @impl Transport
  defdelegate subscribe(transport, pid, tag), to: Transport

  @impl Transport
  defdelegate unsubscribe(transport, pid), to: Transport

  @impl Transport
  defdelegate close(transport), to: Transport

  @impl Transport
  defdelegate force_close(transport), to: Transport

  @impl Transport
  defdelegate interrupt(transport), to: Transport

  @impl Transport
  defdelegate status(transport), to: Transport

  @impl Transport
  defdelegate end_input(transport), to: Transport

  @impl Transport
  defdelegate stderr(transport), to: Transport

  @impl Transport
  defdelegate info(transport), to: Transport
end
