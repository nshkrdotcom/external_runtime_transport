defmodule ExternalRuntimeTransport.Transport.SubprocessTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias ExternalRuntimeTransport.ProcessExit
  alias ExternalRuntimeTransport.Transport
  alias ExternalRuntimeTransport.Transport.{Error, Subprocess}

  test "eager startup streams stdout and a normalized exit to tagged subscribers" do
    ref = make_ref()
    script = create_test_script("printf 'alpha\\nbeta\\n'")

    assert {:ok, transport} = Subprocess.start(command: script, subscriber: {self(), ref})

    assert_receive {:external_runtime_transport, ^ref, {:message, "alpha"}}, 2_000
    assert_receive {:external_runtime_transport, ^ref, {:message, "beta"}}, 2_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref)

    assert :disconnected == Subprocess.status(transport)
  end

  test "legacy subscribers receive bare transport tuples" do
    script = create_test_script("printf 'legacy\\n'")

    assert {:ok, _transport} = Subprocess.start(command: script, subscriber: {self(), :legacy})

    assert_receive {:transport_message, "legacy"}, 2_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_legacy_event()
  end

  test "start returns a structured error when the command cannot be spawned" do
    assert {:error, {:transport, %Error{reason: {:command_not_found, "/tmp/definitely_missing"}}}} =
             Subprocess.start(command: "/tmp/definitely_missing")
  end

  test "lazy startup returns deterministic preflight failures without booting the transport" do
    missing_cwd =
      Path.join(
        System.tmp_dir!(),
        "external_runtime_transport_missing_#{System.unique_integer([:positive])}"
      )

    assert capture_log(fn ->
             assert {:error, {:transport, %Error{reason: {:cwd_not_found, ^missing_cwd}}}} =
                      Subprocess.start(
                        command: System.find_executable("cat") || "/bin/cat",
                        startup_mode: :lazy,
                        cwd: missing_cwd
                      )
           end) == ""
  end

  test "send and end_input roundtrip with a custom event tag" do
    ref = make_ref()

    script =
      create_test_script("""
      while IFS= read -r line; do
        printf 'echo:%s\\n' "$line"
      done
      printf 'done\\n'
      """)

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               event_tag: :custom_transport
             )

    assert Transport.delivery_info(transport).tagged_event_tag == :custom_transport

    assert :ok = Transport.send(transport, ["hello"])
    assert :ok = Transport.end_input(transport)

    assert_receive message, 2_000
    assert {:ok, {:message, "echo:hello"}} = Transport.extract_event(message, ref)

    assert_receive message, 2_000
    assert {:ok, {:message, "done"}} = Transport.extract_event(message, ref)

    assert_receive message, 2_000

    assert {:ok, {:exit, %ProcessExit{status: :success, code: 0}}} =
             Transport.extract_event(message, ref)
  end

  test "buffers early events until the first subscriber attaches when configured" do
    ref = make_ref()
    long_line = String.duplicate("a", 64)
    script = create_test_script("printf '#{long_line}\\nnext\\n'")

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               max_buffer_size: 16,
               oversize_line_chunk_bytes: 8,
               max_recoverable_line_bytes: 128,
               buffer_events_until_subscribe?: true
             )

    assert :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:external_runtime_transport, ^ref, {:message, ^long_line}}, 2_000
    assert_receive {:external_runtime_transport, ^ref, {:message, "next"}}, 2_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref)
  end

  test "raw stdout mode preserves exact bytes and exposes transport metadata" do
    ref = make_ref()
    script = create_test_script("cat")

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               stdout_mode: :raw,
               stdin_mode: :raw
             )

    assert %Transport.Info{} = info = Transport.info(transport)
    assert info.status == :connected
    assert info.stdout_mode == :raw
    assert info.stdin_mode == :raw
    assert info.pty? == false
    assert is_pid(info.pid)
    assert is_integer(info.os_pid)
    assert info.os_pid > 0
    assert info.delivery.legacy? == true
    assert info.delivery.tagged_event_tag == :external_runtime_transport

    assert :ok = Transport.send(transport, "alpha")
    assert :ok = Transport.end_input(transport)

    assert_receive {:external_runtime_transport, ^ref, {:data, "alpha"}}, 2_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref)
  end

  test "short-lived local subprocesses keep the shared exec worker stable across exits" do
    script = create_test_script("printf 'ready\\n'")

    Enum.each([{"pipe", []}, {"pty", [pty?: true]}], fn {label, opts} ->
      ref = make_ref()

      assert {:ok, transport} =
               Subprocess.start(Keyword.merge([command: script, subscriber: {self(), ref}], opts)),
             "failed to start #{label} transport"

      exec_pid = Process.whereis(:exec)
      assert is_pid(exec_pid), "expected shared exec worker for #{label} transport"
      monitor_ref = Process.monitor(exec_pid)

      assert_receive {:external_runtime_transport, ^ref, {:message, "ready"}}, 2_000
      assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref)

      assert :disconnected == Transport.status(transport)
      refute_receive {:DOWN, ^monitor_ref, :process, ^exec_pid, _reason}, 0
      assert Process.whereis(:exec) == exec_pid

      Process.demonitor(monitor_ref, [:flush])
    end)
  end

  test "configured stdin interrupt payloads are written exactly to stdin" do
    ref = make_ref()

    script =
      create_test_script("""
      IFS= read -r line

      if [ "$line" = "quit" ]; then
        exit 130
      fi

      exit 1
      """)

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               stdout_mode: :raw,
               stdin_mode: :raw,
               interrupt_mode: {:stdin, "quit\n"}
             )

    assert %Transport.Info{pty?: false, interrupt_mode: {:stdin, "quit\n"}} =
             Transport.info(transport)

    assert :ok = Transport.interrupt(transport)
    assert {:exit, %ProcessExit{code: 130}} = assert_tagged_event(ref)
  end

  test "close_stdin_on_start closes stdin immediately after boot" do
    ref = make_ref()

    script =
      create_test_script("""
      cat >/dev/null
      printf 'done\\n'
      """)

    assert {:ok, _transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               close_stdin_on_start?: true
             )

    assert_receive {:external_runtime_transport, ^ref, {:message, "done"}}, 2_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref)
  end

  test "last unsubscribe starts the headless timeout" do
    script =
      create_test_script("""
      while IFS= read -r line; do
        printf '%s\\n' "$line"
      done
      """)

    assert {:ok, transport} =
             Subprocess.start(command: script, headless_timeout_ms: 50)

    monitor = Process.monitor(transport)
    assert :ok = Transport.subscribe(transport, self())
    assert :ok = Transport.unsubscribe(transport, self())

    assert_receive {:DOWN, ^monitor, :process, ^transport, :normal}, 2_000
  end

  test "monitor-based subscriber cleanup keeps the transport alive until the last subscriber leaves" do
    ref = make_ref()

    script =
      create_test_script("""
      while IFS= read -r line; do
        printf '%s\\n' "$line"
      done
      """)

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               headless_timeout_ms: 100
             )

    parent = self()
    child_ref = make_ref()

    child =
      spawn(fn ->
        :ok = Transport.subscribe(transport, self(), child_ref)
        send(parent, :child_subscribed)

        receive do
          {:external_runtime_transport, ^child_ref, {:message, line}} ->
            send(parent, {:child_message, line})

          :stop ->
            :ok
        end
      end)

    assert_receive :child_subscribed, 1_000

    assert :ok = Transport.send(transport, "fanout")
    assert_receive {:external_runtime_transport, ^ref, {:message, "fanout"}}, 2_000
    assert_receive {:child_message, "fanout"}, 2_000

    child_monitor = Process.monitor(child)
    send(child, :stop)
    assert_receive {:DOWN, ^child_monitor, :process, ^child, reason}, 2_000
    assert reason in [:normal, :noproc]

    assert :connected == Transport.status(transport)
    assert :ok = Transport.unsubscribe(transport, self())
  end

  test "stderr is dispatched in realtime, retained in a ring buffer, and callback lines flush on exit" do
    ref = make_ref()
    parent = self()
    gate_path = temp_path!("stderr_gate")

    script =
      create_test_script("""
      printf 'err-one\\nerr-two' >&2
      while [ ! -f "#{gate_path}" ]; do
        sleep 0.01
      done
      printf 'out\\n'
      """)

    assert {:ok, _transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               max_stderr_buffer_size: 8,
               stderr_callback: fn line -> send(parent, {:stderr_line, line}) end
             )

    assert_receive {:stderr_line, "err-one"}, 2_000
    assert_receive {:external_runtime_transport, ^ref, {:stderr, stderr_chunk}}, 2_000

    assert stderr_chunk =~ "err-one"
    File.write!(gate_path, "release")
    assert_receive {:external_runtime_transport, ^ref, {:message, "out"}}, 2_000
    assert_receive {:stderr_line, "err-two"}, 2_000

    assert {:exit, %ProcessExit{status: :success, code: 0, stderr: "\nerr-two"}} =
             assert_tagged_event(ref)
  end

  test "extract_event unwraps legacy transport tuples" do
    assert {:ok, {:message, "legacy"}} = Transport.extract_event({:transport_message, "legacy"})
    assert :error = Transport.extract_event({:unexpected, :message})
  end

  test "late subscribers can receive the retained stderr tail from the core" do
    ref = make_ref()
    gate_path = temp_path!("late_stderr_gate")

    script =
      create_test_script("""
      printf 'late stderr' >&2
      while [ ! -f "#{gate_path}" ]; do
        sleep 0.01
      done
      """)

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               replay_stderr_on_subscribe?: true
             )

    assert wait_until(fn -> Transport.stderr(transport) == "late stderr" end, 1_000) == :ok

    assert :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:external_runtime_transport, ^ref, {:stderr, "late stderr"}}, 2_000
    File.write!(gate_path, "release")

    assert {:exit, %ProcessExit{status: :success, code: 0, stderr: "late stderr"}} =
             assert_tagged_event(ref)
  end

  test "fast-exit stderr is retained for late subscribers" do
    ref = make_ref()
    script = create_test_script("printf 'fast stderr' >&2")

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               replay_stderr_on_subscribe?: true
             )

    assert :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:external_runtime_transport, ^ref, {:stderr, "fast stderr"}}, 2_000

    assert {:exit, %ProcessExit{status: :success, code: 0, stderr: "fast stderr"}} =
             assert_tagged_event(ref)
  end

  test "oversized stdout below the recoverable ceiling is chunk-recovered intact" do
    ref = make_ref()
    long_line = String.duplicate("x", 48)

    script =
      create_test_script("""
      python3 - <<'PY'
      print('x' * 48)
      print('after')
      PY
      """)

    assert {:ok, _transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               max_buffer_size: 16,
               oversize_line_chunk_bytes: 8,
               max_recoverable_line_bytes: 64
             )

    assert_receive {:external_runtime_transport, ^ref, {:message, ^long_line}}, 5_000
    assert_receive {:external_runtime_transport, ^ref, {:message, "after"}}, 5_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref, 5_000)
  end

  test "oversized stdout above the recoverable ceiling emits a fatal structured overflow" do
    ref = make_ref()

    script =
      create_test_script("""
      python3 - <<'PY'
      import sys
      import time

      sys.stdout.write('x' * 40)
      sys.stdout.flush()
      time.sleep(0.1)
      sys.stdout.write('x' * 56 + '\\n')
      sys.stdout.flush()
      print('after')
      PY
      """)

    assert {:ok, transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               max_buffer_size: 16,
               oversize_line_chunk_bytes: 8,
               max_recoverable_line_bytes: 64
             )

    assert {:error, %Error{reason: {:buffer_overflow, actual_size, 64}, context: context}} =
             assert_tagged_event(ref, 5_000)

    assert actual_size > 64
    assert context.mode == :chunk_then_fail
    assert context.buffer_overflow_mode == :fatal
    assert context.line_recovery_attempted? == true
    assert context.max_recoverable_line_bytes == 64
    assert context.oversize_line_chunk_bytes == 8
    assert context.chunk_count > 0
    assert context.first_fatal? == true

    assert {:exit, %ProcessExit{status: :error, reason: {:buffer_overflow, _, 64}}} =
             assert_tagged_event(ref, 5_000)

    refute_receive {:external_runtime_transport, ^ref, {:message, "after"}}, 250
    assert :disconnected == Subprocess.status(transport)
  end

  test "large stdout fragments below the buffer limit are flushed intact on exit" do
    ref = make_ref()
    large_line = String.duplicate("x", 262_144)

    script =
      create_test_script("""
      head -c 262144 /dev/zero | tr '\\0' 'x'
      """)

    assert {:ok, _transport} =
             Subprocess.start(
               command: script,
               subscriber: {self(), ref},
               max_buffer_size: byte_size(large_line) + 1_024
             )

    assert_receive {:external_runtime_transport, ^ref, {:message, ^large_line}}, 5_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref, 5_000)
  end

  test "post-exit stdout flush preserves the trailing fragment exactly" do
    ref = make_ref()
    fragment = "  trailing fragment  "
    script = create_test_script("printf '#{fragment}'")

    assert {:ok, _transport} = Subprocess.start(command: script, subscriber: {self(), ref})

    assert_receive {:external_runtime_transport, ^ref, {:message, ^fragment}}, 2_000
    assert {:exit, %ProcessExit{status: :success, code: 0}} = assert_tagged_event(ref)
  end

  test "interrupt supports in-flight subprocesses and surfaces the resulting exit" do
    ref = make_ref()
    ready_path = temp_path!("interrupt_ready")

    script =
      create_test_script("""
      trap 'printf "interrupted\\n" >&2; exit 130' INT
      : > "#{ready_path}"
      sleep 60
      """)

    assert {:ok, transport} = Subprocess.start(command: script, subscriber: {self(), ref})
    assert wait_until(fn -> File.exists?(ready_path) end, 1_000) == :ok

    assert :ok = Transport.interrupt(transport)

    assert {:stderr, "interrupted\n"} = assert_tagged_event(ref)
    assert {:exit, %ProcessExit{} = exit} = assert_tagged_event(ref)
    refute ProcessExit.successful?(exit)
  end

  test "interrupt and close races complete without leaving the caller hanging" do
    script =
      create_test_script("""
      trap 'exit 130' INT
      sleep 60
      """)

    assert {:ok, transport} = Subprocess.start(command: script)

    interrupt_task =
      Task.async(fn ->
        Transport.interrupt(transport)
      end)

    assert :ok = Transport.close(transport)

    case Task.await(interrupt_task, 2_000) do
      :ok ->
        :ok

      {:error, {:transport, %Error{reason: :not_connected}}} ->
        :ok

      {:error, {:transport, %Error{reason: :transport_stopped}}} ->
        :ok
    end
  end

  test "force_close stops the transport immediately" do
    script = create_test_script("sleep 60")

    assert {:ok, transport} = Subprocess.start(command: script)
    monitor = Process.monitor(transport)

    assert :ok = Transport.force_close(transport)
    assert_receive {:DOWN, ^monitor, :process, ^transport, :normal}, 2_000
  end

  test "force_close stops a suspended transport through the system control path" do
    script = create_test_script("sleep 60")

    assert {:ok, transport} = Subprocess.start(command: script)

    try do
      monitor = Process.monitor(transport)
      :ok = :sys.suspend(transport)

      assert :ok = Transport.force_close(transport)
      assert_receive {:DOWN, ^monitor, :process, ^transport, :normal}, 2_000
    after
      if Process.alive?(transport) do
        Process.exit(transport, :kill)
      end
    end
  end

  test "calls after transport exit return structured not_connected errors" do
    script = create_test_script("exit 0")

    assert {:ok, transport} = Subprocess.start(command: script)
    monitor = Process.monitor(transport)

    assert_receive {:DOWN, ^monitor, :process, ^transport, :normal}, 2_000

    assert {:error, {:transport, %Error{reason: :not_connected}}} =
             Transport.send(transport, "hello")

    assert {:error, {:transport, %Error{reason: :not_connected}}} =
             Transport.end_input(transport)

    assert {:error, {:transport, %Error{reason: :not_connected}}} =
             Transport.interrupt(transport)

    assert :disconnected == Transport.status(transport)
    assert "" == Transport.stderr(transport)
  end

  defp create_test_script(body) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "external_runtime_transport_transport_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    path = Path.join(dir, "fixture.sh")

    File.write!(path, """
    #!/usr/bin/env bash
    set -euo pipefail
    #{body}
    """)

    File.chmod!(path, 0o755)

    on_exit(fn ->
      File.rm_rf!(dir)
    end)

    path
  end

  defp temp_path!(name) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "external_runtime_transport_transport_tmp_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    on_exit(fn ->
      File.rm_rf!(dir)
    end)

    Path.join(dir, name)
  end

  defp assert_tagged_event(ref, timeout \\ 2_000) do
    assert_receive message, timeout
    assert {:ok, event} = Transport.extract_event(message, ref)
    event
  end

  defp assert_legacy_event(timeout \\ 2_000) do
    assert_receive message, timeout
    assert {:ok, event} = Transport.extract_event(message)
    event
  end

  defp wait_until(fun, timeout_ms) when is_function(fun, 0) and is_integer(timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(fun, deadline)
  end

  defp do_wait_until(fun, deadline_ms) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline_ms do
        :timeout
      else
        Process.sleep(5)
        do_wait_until(fun, deadline_ms)
      end
    end
  end
end
