defmodule ExternalRuntimeTransport.Transport do
  @moduledoc """
  Legacy compatibility facade above the Execution Plane-owned long-lived process
  transport substrate.
  """

  alias ExecutionPlane.Process.Transport, as: RuntimeTransport
  alias ExecutionPlane.Process.Transport.Delivery
  alias ExecutionPlane.Process.Transport.Error, as: RuntimeError
  alias ExecutionPlane.Process.Transport.Info, as: RuntimeInfo
  alias ExecutionPlane.Process.Transport.RunResult, as: RuntimeRunResult

  alias ExternalRuntimeTransport.{
    Command,
    ProcessExit,
    Transport.Error,
    Transport.Info,
    Transport.RunResult
  }

  alias ExternalRuntimeTransport.ExecutionSurface.Capabilities
  alias ExternalRuntimeTransport.Transport.Delivery, as: LegacyDelivery

  @typedoc "Opaque transport reference."
  @type t :: pid()

  @typedoc "Legacy subscribers use `:legacy`; tagged subscribers use a reference."
  @type subscription_tag :: :legacy | reference()

  @typedoc "The tagged event atom prefix."
  @type event_tag :: atom()

  @typedoc "Generic execution-surface placement kind."
  @type surface_kind :: :local_subprocess | :ssh_exec | :guest_bridge

  @typedoc "Transport events delivered to subscribers."
  @type message ::
          {:transport_message, binary()}
          | {:transport_data, binary()}
          | {:transport_error, Error.t()}
          | {:transport_stderr, binary()}
          | {:transport_exit, ProcessExit.t()}
          | {event_tag(), reference(), {:message, binary()}}
          | {event_tag(), reference(), {:data, binary()}}
          | {event_tag(), reference(), {:error, Error.t()}}
          | {event_tag(), reference(), {:stderr, binary()}}
          | {event_tag(), reference(), {:exit, ProcessExit.t()}}

  @typedoc "Normalized transport event payload extracted from a mailbox message."
  @type extracted_event ::
          {:message, binary()}
          | {:data, binary()}
          | {:error, Error.t()}
          | {:stderr, binary()}
          | {:exit, ProcessExit.t()}

  @callback start(keyword()) :: {:ok, t()} | {:error, {:transport, Error.t()}}
  @callback start_link(keyword()) :: {:ok, t()} | {:error, {:transport, Error.t()}}
  @callback run(Command.t(), keyword()) ::
              {:ok, RunResult.t()} | {:error, {:transport, Error.t()}}
  @callback send(t(), iodata() | map() | list()) :: :ok | {:error, {:transport, Error.t()}}
  @callback subscribe(t(), pid()) :: :ok | {:error, {:transport, Error.t()}}
  @callback subscribe(t(), pid(), subscription_tag()) ::
              :ok | {:error, {:transport, Error.t()}}
  @callback unsubscribe(t(), pid()) :: :ok
  @callback close(t()) :: :ok
  @callback force_close(t()) :: :ok | {:error, {:transport, Error.t()}}
  @callback interrupt(t()) :: :ok | {:error, {:transport, Error.t()}}
  @callback status(t()) :: :connected | :disconnected | :error
  @callback end_input(t()) :: :ok | {:error, {:transport, Error.t()}}
  @callback stderr(t()) :: binary()
  @callback info(t()) :: Info.t()

  @spec start(keyword()) :: {:ok, t()} | {:error, {:transport, Error.t()}}
  def start(opts) when is_list(opts) do
    opts
    |> normalize_opts()
    |> RuntimeTransport.start()
    |> normalize_transport_result()
  end

  @spec start_link(keyword()) :: {:ok, t()} | {:error, {:transport, Error.t()}}
  def start_link(opts) when is_list(opts) do
    opts
    |> normalize_opts()
    |> RuntimeTransport.start_link()
    |> normalize_transport_result()
  end

  @spec run(Command.t(), keyword()) :: {:ok, RunResult.t()} | {:error, {:transport, Error.t()}}
  def run(%Command{} = command, opts \\ []) when is_list(opts) do
    command
    |> to_runtime_command()
    |> RuntimeTransport.run(normalize_opts(opts))
    |> normalize_run_result()
  end

  @spec send(t(), iodata() | map() | list()) :: :ok | {:error, {:transport, Error.t()}}
  def send(transport, message) when is_pid(transport),
    do: normalize_transport_result(RuntimeTransport.send(transport, message))

  @spec subscribe(t(), pid()) :: :ok | {:error, {:transport, Error.t()}}
  def subscribe(transport, pid) when is_pid(transport) and is_pid(pid),
    do: normalize_transport_result(RuntimeTransport.subscribe(transport, pid))

  @spec subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, {:transport, Error.t()}}
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and (tag == :legacy or is_reference(tag)),
      do: normalize_transport_result(RuntimeTransport.subscribe(transport, pid, tag))

  def subscribe(_transport, _pid, tag) do
    {:error, {:transport, Error.invalid_options({:invalid_subscriber, tag})}}
  end

  @spec unsubscribe(t(), pid()) :: :ok
  def unsubscribe(transport, pid) when is_pid(transport) and is_pid(pid),
    do: RuntimeTransport.unsubscribe(transport, pid)

  @spec close(t()) :: :ok
  def close(transport) when is_pid(transport), do: RuntimeTransport.close(transport)

  @spec force_close(t()) :: :ok | {:error, {:transport, Error.t()}}
  def force_close(transport) when is_pid(transport),
    do: normalize_transport_result(RuntimeTransport.force_close(transport))

  @spec interrupt(t()) :: :ok | {:error, {:transport, Error.t()}}
  def interrupt(transport) when is_pid(transport),
    do: normalize_transport_result(RuntimeTransport.interrupt(transport))

  @spec status(t()) :: :connected | :disconnected | :error
  def status(transport) when is_pid(transport), do: RuntimeTransport.status(transport)

  @spec end_input(t()) :: :ok | {:error, {:transport, Error.t()}}
  def end_input(transport) when is_pid(transport),
    do: normalize_transport_result(RuntimeTransport.end_input(transport))

  @spec stderr(t()) :: binary()
  def stderr(transport) when is_pid(transport), do: RuntimeTransport.stderr(transport)

  @spec info(t()) :: Info.t()
  def info(transport) when is_pid(transport) do
    transport
    |> RuntimeTransport.info()
    |> to_legacy_info()
  end

  @spec extract_event(term()) :: {:ok, extracted_event()} | :error
  def extract_event(message) do
    case RuntimeTransport.extract_event(message) do
      {:ok, event} -> {:ok, to_legacy_event(event)}
      :error -> :error
    end
  end

  @spec extract_event(term(), reference()) :: {:ok, extracted_event()} | :error
  def extract_event(message, ref) when is_reference(ref) do
    case RuntimeTransport.extract_event(message, ref) do
      {:ok, event} -> {:ok, to_legacy_event(event)}
      :error -> :error
    end
  end

  def extract_event(message, _ref), do: extract_event(message)

  @spec delivery_info(t()) :: LegacyDelivery.t()
  def delivery_info(transport) when is_pid(transport) do
    transport
    |> RuntimeTransport.delivery_info()
    |> to_legacy_delivery()
  end

  defp normalize_opts(opts) do
    opts
    |> Keyword.put_new(:event_tag, :external_runtime_transport)
    |> maybe_put_runtime_command(:command)
    |> maybe_put_runtime_command(:invocation_override)
  end

  defp maybe_put_runtime_command(opts, key) do
    case Keyword.get(opts, key) do
      %Command{} = command -> Keyword.put(opts, key, to_runtime_command(command))
      _other -> opts
    end
  end

  defp normalize_transport_result({:error, {:transport, %RuntimeError{} = error}}) do
    {:error, {:transport, to_legacy_error(error)}}
  end

  defp normalize_transport_result(other), do: other

  defp normalize_run_result({:ok, %RuntimeRunResult{} = result}),
    do: {:ok, to_legacy_run_result(result)}

  defp normalize_run_result(other), do: normalize_transport_result(other)

  defp to_runtime_command(%Command{} = command) do
    ExecutionPlane.Command.new(
      command.command,
      command.args,
      cwd: command.cwd,
      env: command.env,
      clear_env?: command.clear_env?,
      user: command.user
    )
  end

  defp to_legacy_command(nil), do: nil

  defp to_legacy_command(%ExecutionPlane.Command{} = command) do
    Command.new(
      command.command,
      command.args,
      cwd: command.cwd,
      env: command.env,
      clear_env?: command.clear_env?,
      user: command.user
    )
  end

  defp to_legacy_capabilities(nil), do: nil

  defp to_legacy_capabilities(capabilities) do
    capabilities
    |> Map.from_struct()
    |> Capabilities.new!()
  end

  defp to_legacy_delivery(nil), do: nil

  defp to_legacy_delivery(%Delivery{tagged_event_tag: tagged_event_tag}) do
    LegacyDelivery.new(tagged_event_tag)
  end

  defp to_legacy_error(%RuntimeError{} = error) do
    %Error{
      reason: error.reason,
      message: error.message,
      context: error.context
    }
  end

  defp to_legacy_process_exit(%ExecutionPlane.ProcessExit{} = exit) do
    %ProcessExit{
      status: exit.status,
      code: exit.code,
      signal: exit.signal,
      reason: exit.reason,
      stderr: exit.stderr
    }
  end

  defp to_legacy_run_result(%RuntimeRunResult{} = result) do
    %RunResult{
      invocation: to_legacy_command(result.invocation),
      output: result.output,
      stdout: result.stdout,
      stderr: result.stderr,
      exit: to_legacy_process_exit(result.exit),
      stderr_mode: result.stderr_mode
    }
  end

  defp to_legacy_info(%RuntimeInfo{} = info) do
    %Info{
      invocation: to_legacy_command(info.invocation),
      pid: info.pid,
      os_pid: info.os_pid,
      surface_kind: info.surface_kind,
      target_id: info.target_id,
      lease_ref: info.lease_ref,
      surface_ref: info.surface_ref,
      boundary_class: info.boundary_class,
      observability: info.observability,
      adapter_capabilities: to_legacy_capabilities(info.adapter_capabilities),
      effective_capabilities: to_legacy_capabilities(info.effective_capabilities),
      bridge_profile: info.bridge_profile,
      protocol_version: info.protocol_version,
      extensions: info.extensions,
      adapter_metadata: info.adapter_metadata,
      status: info.status,
      stdout_mode: info.stdout_mode,
      stdin_mode: info.stdin_mode,
      pty?: info.pty?,
      interrupt_mode: info.interrupt_mode,
      stderr: info.stderr,
      delivery: to_legacy_delivery(info.delivery)
    }
  end

  defp to_legacy_event({:error, %RuntimeError{} = error}), do: {:error, to_legacy_error(error)}

  defp to_legacy_event({:exit, %ExecutionPlane.ProcessExit{} = exit}),
    do: {:exit, to_legacy_process_exit(exit)}

  defp to_legacy_event(event), do: event
end
