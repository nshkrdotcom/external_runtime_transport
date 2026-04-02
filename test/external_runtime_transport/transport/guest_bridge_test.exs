defmodule ExternalRuntimeTransport.Transport.GuestBridgeTest do
  use ExUnit.Case, async: false

  alias ExternalRuntimeTransport.Command
  alias ExternalRuntimeTransport.ProcessExit
  alias ExternalRuntimeTransport.TestSupport.FakeGuestBridge
  alias ExternalRuntimeTransport.Transport
  alias ExternalRuntimeTransport.Transport.RunResult

  test "run/2 executes over the guest bridge through the generic execution-surface seam" do
    fake_bridge = FakeGuestBridge.new!()
    on_exit(fn -> FakeGuestBridge.cleanup(fake_bridge) end)

    assert {:ok, %RunResult{} = result} =
             Transport.run(
               Command.new("guest-runner", ["--mode", "run"]),
               surface_kind: :guest_bridge,
               transport_options: FakeGuestBridge.transport_options(fake_bridge),
               adapter_metadata: FakeGuestBridge.adapter_metadata(fake_bridge)
             )

    assert result.stdout == "guest-run:guest-runner --mode run\n"
    assert result.stderr == "guest-run-stderr\n"
    assert result.output == "guest-run:guest-runner --mode run\n"
    assert result.exit.status == :success
    assert result.exit.code == 0
  end

  test "start/1 streams over the guest bridge and exposes bridge metadata" do
    ref = make_ref()
    fake_bridge = FakeGuestBridge.new!()
    on_exit(fn -> FakeGuestBridge.cleanup(fake_bridge) end)

    assert {:ok, transport} =
             Transport.start(
               command: "guest-session",
               subscriber: {self(), ref},
               stdout_mode: :raw,
               stdin_mode: :raw,
               surface_kind: :guest_bridge,
               target_id: "target-1",
               lease_ref: "lease-1",
               surface_ref: "surface-1",
               boundary_class: :guest,
               observability: %{suite: :guest_bridge},
               transport_options: FakeGuestBridge.transport_options(fake_bridge),
               adapter_metadata: FakeGuestBridge.adapter_metadata(fake_bridge)
             )

    assert %Transport.Info{} = info = Transport.info(transport)
    assert info.surface_kind == :guest_bridge
    assert info.target_id == "target-1"
    assert info.lease_ref == "lease-1"
    assert info.surface_ref == "surface-1"
    assert info.boundary_class == :guest
    assert info.observability == %{suite: :guest_bridge}
    assert info.bridge_profile == "core_cli_transport"
    assert info.protocol_version == 1
    assert info.adapter_metadata.bridge_ref == "bridge-1"
    assert info.adapter_metadata.bridge_session_ref == "guest-session-1"
    assert info.effective_capabilities.path_semantics == :guest
    assert info.effective_capabilities.interrupt_kind == :rpc

    assert :ok = Transport.send(transport, "alpha")
    assert :ok = Transport.end_input(transport)

    assert_receive {:external_runtime_transport, ^ref, {:data, "guest-session:alpha"}}, 2_000
    assert_receive {:external_runtime_transport, ^ref, {:stderr, "guest-session-stderr\n"}}, 2_000

    assert_receive {:external_runtime_transport, ^ref,
                    {:exit, %ProcessExit{status: :success, code: 0}}},
                   2_000
  end
end
