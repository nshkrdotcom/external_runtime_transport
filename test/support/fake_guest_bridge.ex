defmodule ExternalRuntimeTransport.TestSupport.FakeGuestBridge do
  @moduledoc false

  use GenServer

  alias ExternalRuntimeTransport.ExecutionSurface.Capabilities
  alias ExternalRuntimeTransport.Transport.GuestBridge.Protocol

  defstruct server_pid: nil,
            bridge_ref: "bridge-1",
            bridge_profile: "core_cli_transport",
            endpoint_path: nil

  @type t :: %__MODULE__{
          server_pid: pid(),
          bridge_ref: String.t(),
          bridge_profile: String.t(),
          endpoint_path: String.t()
        }

  @spec new!(keyword()) :: t()
  def new!(opts \\ []) when is_list(opts) do
    bridge_ref = Keyword.get(opts, :bridge_ref, "bridge-1")
    bridge_profile = Keyword.get(opts, :bridge_profile, "core_cli_transport")

    {:ok, server_pid} =
      GenServer.start_link(__MODULE__, %{
        bridge_profile: bridge_profile,
        capabilities: Keyword.get(opts, :capabilities, default_capabilities())
      })

    %__MODULE__{
      server_pid: server_pid,
      bridge_ref: bridge_ref,
      bridge_profile: bridge_profile,
      endpoint_path:
        Path.join(
          System.tmp_dir!(),
          "external_runtime_transport_fake_guest_bridge_#{System.unique_integer([:positive])}.sock"
        )
    }
  end

  @spec cleanup(t()) :: :ok
  def cleanup(%__MODULE__{server_pid: server_pid}) do
    if is_pid(server_pid) and Process.alive?(server_pid) do
      Process.exit(server_pid, :shutdown)
    end

    :ok
  end

  @spec transport_options(t(), keyword()) :: keyword()
  def transport_options(%__MODULE__{} = bridge, opts \\ []) when is_list(opts) do
    [
      endpoint: %{
        kind: :unix_socket,
        path: Keyword.get(opts, :endpoint_path, bridge.endpoint_path)
      },
      bridge_ref: Keyword.get(opts, :bridge_ref, bridge.bridge_ref),
      bridge_profile: Keyword.get(opts, :bridge_profile, bridge.bridge_profile),
      supported_protocol_versions: Keyword.get(opts, :supported_protocol_versions, [1])
    ]
  end

  @spec adapter_metadata(t()) :: map()
  def adapter_metadata(%__MODULE__{server_pid: server_pid}) do
    %{test_connection: server_pid}
  end

  @impl GenServer
  def init(%{bridge_profile: bridge_profile, capabilities: capabilities}) do
    {:ok,
     %{
       active_receiver: nil,
       bridge_profile: bridge_profile,
       capabilities: capabilities,
       queue: :queue.new(),
       session_command: "guest-session",
       stdin: ""
     }}
  end

  @impl GenServer
  def handle_call({:send_frame, %{"kind" => "request"} = frame}, _from, state) do
    {:reply, :ok, frame |> process_request(state) |> maybe_deliver_chunk()}
  end

  def handle_call({:recv_chunk, _timeout_ms}, _from, state) do
    case :queue.out(state.queue) do
      {{:value, chunk}, queue} ->
        {:reply, {:ok, chunk}, %{state | queue: queue}}

      {:empty, _queue} ->
        {:reply, {:error, :timeout}, state}
    end
  end

  def handle_call({:activate, receiver}, _from, state) when is_pid(receiver) do
    {:reply, :ok, state |> Map.put(:active_receiver, receiver) |> maybe_deliver_chunk()}
  end

  def handle_call(:close, _from, state) do
    if is_pid(state.active_receiver) do
      Kernel.send(state.active_receiver, {:bridge_closed, self()})
    end

    {:stop, :normal, :ok, state}
  end

  defp process_request(%{"id" => id, "op" => "attach", "payload" => payload}, state) do
    response_payload = %{
      "bridge_session_ref" => "guest-session-1",
      "bridge_profile" => Map.get(payload, "bridge_profile", state.bridge_profile),
      "protocol_version" => 1,
      "effective_capabilities" => Protocol.capabilities_to_external(state.capabilities),
      "extensions" => %{"transport" => "fake_guest_bridge"}
    }

    enqueue_frame(state, Protocol.response(id, true, response_payload))
  end

  defp process_request(%{"id" => id, "op" => "run", "payload" => payload}, state) do
    command = Map.get(payload, "command", "guest-runner")
    args = normalize_args(Map.get(payload, "args", []))

    response_payload = %{
      "stdout" => "guest-run:" <> Enum.join([command | args], " ") <> "\n",
      "stderr" => "guest-run-stderr\n",
      "stderr_mode" => "separate",
      "exit" => %{"status" => "success", "code" => 0}
    }

    enqueue_frame(state, Protocol.response(id, true, response_payload))
  end

  defp process_request(%{"id" => id, "op" => "start_session", "payload" => payload}, state) do
    state =
      state
      |> enqueue_frame(Protocol.response(id, true, %{"started" => true}))
      |> Map.put(:session_command, Map.get(payload, "command", state.session_command))

    state
  end

  defp process_request(%{"id" => id, "op" => "stdin", "payload" => payload}, state) do
    {:ok, stdin} =
      payload
      |> Map.get("data")
      |> Protocol.decode_bytes()

    state
    |> enqueue_frame(Protocol.response(id, true, %{}))
    |> Map.put(:stdin, state.stdin <> (stdin || ""))
  end

  defp process_request(%{"id" => id, "op" => "stdin_eof"}, state) do
    state
    |> enqueue_frame(Protocol.response(id, true, %{}))
    |> enqueue_frame(
      Protocol.event("stdout", %{
        "data" => Protocol.encode_bytes("#{state.session_command}:#{state.stdin}")
      })
    )
    |> enqueue_frame(
      Protocol.event("stderr", %{
        "data" => Protocol.encode_bytes("#{state.session_command}-stderr\n")
      })
    )
    |> enqueue_frame(Protocol.event("exit", %{"status" => "success", "code" => 0}))
  end

  defp process_request(%{"id" => id, "op" => "interrupt"}, state) do
    enqueue_frame(state, Protocol.response(id, true, %{}))
  end

  defp process_request(%{"op" => "close"}, state), do: state
  defp process_request(_frame, state), do: state

  defp enqueue_frame(state, frame) do
    %{state | queue: :queue.in(Protocol.encode_frame(frame), state.queue)}
  end

  defp maybe_deliver_chunk(%{active_receiver: receiver} = state) when is_pid(receiver) do
    case :queue.out(state.queue) do
      {{:value, chunk}, queue} ->
        Kernel.send(receiver, {:bridge_data, self(), chunk})
        %{state | queue: queue, active_receiver: nil}

      {:empty, _queue} ->
        state
    end
  end

  defp maybe_deliver_chunk(state), do: state

  defp default_capabilities do
    Capabilities.new!(
      remote?: true,
      startup_kind: :bridge,
      path_semantics: :guest,
      supports_run?: true,
      supports_streaming_stdio?: true,
      supports_pty?: true,
      supports_user?: true,
      supports_env?: true,
      supports_cwd?: true,
      interrupt_kind: :rpc
    )
  end

  defp normalize_args(args) when is_list(args), do: Enum.map(args, &to_string/1)
  defp normalize_args(_other), do: []
end
