defmodule ExternalRuntimeTransportTest do
  use ExUnit.Case
  doctest ExternalRuntimeTransport

  test "exposes canonical metadata" do
    assert ExternalRuntimeTransport.metadata() == %{
             app: :external_runtime_transport,
             domain: :transport,
             module: ExternalRuntimeTransport
           }
  end
end
