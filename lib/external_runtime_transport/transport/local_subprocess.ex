defmodule ExternalRuntimeTransport.Transport.LocalSubprocess do
  @moduledoc false

  alias ExecutionPlane.Process.Transport.LocalSubprocess, as: RuntimeLocalSubprocess
  alias ExternalRuntimeTransport.ExecutionSurface.Adapter
  alias ExternalRuntimeTransport.ExecutionSurface.Capabilities
  alias ExternalRuntimeTransport.Transport

  @behaviour Adapter
  @behaviour Transport

  @impl Adapter
  def surface_kind, do: :local_subprocess

  @impl Adapter
  def capabilities do
    RuntimeLocalSubprocess.capabilities()
    |> Map.from_struct()
    |> Capabilities.new!()
  end

  @impl Adapter
  defdelegate normalize_transport_options(options), to: RuntimeLocalSubprocess

  @impl Transport
  defdelegate start(opts), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate start_link(opts), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate run(command, opts), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate send(transport, message), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate subscribe(transport, pid), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate subscribe(transport, pid, tag), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate unsubscribe(transport, pid), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate close(transport), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate force_close(transport), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate interrupt(transport), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate status(transport), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate end_input(transport), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate stderr(transport), to: ExternalRuntimeTransport.Transport.Subprocess

  @impl Transport
  defdelegate info(transport), to: ExternalRuntimeTransport.Transport.Subprocess
end
