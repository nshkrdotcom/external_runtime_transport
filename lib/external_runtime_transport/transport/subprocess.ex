defmodule ExternalRuntimeTransport.Transport.Subprocess do
  @moduledoc false

  alias ExternalRuntimeTransport.{Command, Transport}

  @behaviour Transport

  @impl Transport
  def start(opts) when is_list(opts),
    do: Transport.start(Keyword.put_new(opts, :surface_kind, :local_subprocess))

  @impl Transport
  def start_link(opts) when is_list(opts),
    do: Transport.start_link(Keyword.put_new(opts, :surface_kind, :local_subprocess))

  @impl Transport
  def run(%Command{} = command, opts) when is_list(opts),
    do: Transport.run(command, Keyword.put_new(opts, :surface_kind, :local_subprocess))

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
