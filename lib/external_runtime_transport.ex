defmodule ExternalRuntimeTransport do
  @moduledoc """
  Legacy compatibility and deprecation shell for the lower runtime substrate
  that moved to Execution Plane in Wave 2.

  `execution_plane` now owns the `execution_surface` contract and the minimal
  local one-shot process substrate. This repo remains for published facade
  compatibility and for the SSH, guest, and long-lived transport mechanics that
  retire in later waves.
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
