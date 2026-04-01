defmodule ExternalRuntimeTransport do
  @moduledoc """
  Minimal runtime metadata and boundary helpers for external transport work.
  """

  @doc """
  Returns the canonical package metadata used by the transport foundation.

  ## Examples

      iex> ExternalRuntimeTransport.metadata()
      %{app: :external_runtime_transport, domain: :transport, module: ExternalRuntimeTransport}

  """
  @spec metadata() :: %{app: atom(), domain: atom(), module: module()}
  def metadata do
    %{
      app: :external_runtime_transport,
      domain: :transport,
      module: __MODULE__
    }
  end
end
