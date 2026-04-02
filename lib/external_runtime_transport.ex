defmodule ExternalRuntimeTransport do
  @moduledoc """
  Shared execution-surface substrate for process placement.

  The package owns the generic `execution_surface` contract plus the raw
  transport adapters that currently land as `:local_subprocess`, `:ssh_exec`,
  and `:guest_bridge`.
  """

  @doc """
  Returns the canonical package metadata used by the transport foundation.

  ## Examples

      iex> ExternalRuntimeTransport.metadata()
      %{app: :external_runtime_transport, domain: :transport, module: ExternalRuntimeTransport}

  """
  @spec metadata() :: %{
          app: :external_runtime_transport,
          domain: :transport,
          module: ExternalRuntimeTransport
        }
  def metadata do
    %{
      app: :external_runtime_transport,
      domain: :transport,
      module: __MODULE__
    }
  end
end
