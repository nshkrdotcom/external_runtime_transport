defmodule ExternalRuntimeTransport.Transport.CapabilityContractTest do
  use ExUnit.Case, async: true

  alias ExternalRuntimeTransport.{Command, Transport}
  alias ExternalRuntimeTransport.Transport.Error

  test "start/1 rejects retired non-final surface owners cleanly" do
    assert {:error, {:transport, %Error{reason: {:invalid_surface_kind, :test_restricted_spawn}}}} =
             Transport.start(command: "cat", surface_kind: :test_restricted_spawn, pty?: true)

    assert {:error, {:transport, %Error{reason: {:invalid_surface_kind, :test_restricted_spawn}}}} =
             Transport.start(
               command: "cat",
               surface_kind: :test_restricted_spawn,
               user: "builder"
             )

    assert {:error, {:transport, %Error{reason: {:invalid_surface_kind, :test_restricted_spawn}}}} =
             Transport.start(
               command: "cat",
               surface_kind: :test_restricted_spawn,
               env: %{"PATH" => "/tmp/bin"}
             )

    assert {:error, {:transport, %Error{reason: {:invalid_surface_kind, :test_restricted_spawn}}}} =
             Transport.start(
               command: "cat",
               surface_kind: :test_restricted_spawn,
               cwd: "/tmp/project"
             )
  end

  test "run/2 rejects retired non-final surface owners cleanly" do
    command = Command.new("echo", [], cwd: "/tmp/project")

    assert {:error, {:transport, %Error{reason: {:invalid_surface_kind, :test_restricted_spawn}}}} =
             Transport.run(command, surface_kind: :test_restricted_spawn)
  end
end
