# Getting Started

`external_runtime_transport` is now the legacy compatibility entrypoint for
callers that still depend on its published APIs.

Execution Plane owns the moved lower substrate after Waves 2, 6, and 7:

- the `execution_surface` contract
- the one-shot process substrate
- the long-lived process transport substrate
- the active local, SSH, and guest placement implementations

Use `/home/home/p/g/n/execution_plane` for new lower-runtime adoption. Keep
this repo only when you still need the historical published facade.

## Install

```elixir
def deps do
  [
    {:external_runtime_transport, "~> 0.1.0"}
  ]
end
```

## One-Shot Commands

Use `ExternalRuntimeTransport.Transport.run/2` only when you need the legacy
compatibility surface:

```elixir
alias ExternalRuntimeTransport.Command
alias ExternalRuntimeTransport.Transport

{:ok, result} =
  Transport.run(
    Command.new("sh", ["-c", "printf ready"])
  )
```

The same call can move onto a different surface by changing
`execution_surface`:

```elixir
{:ok, result} =
  Transport.run(
    Command.new("hostname"),
    execution_surface: [
      surface_kind: :ssh_exec,
      transport_options: [
        destination: "buildbox.example",
        ssh_user: "deploy"
      ]
    ]
  )
```

## Long-Lived Transports

Use `ExternalRuntimeTransport.Transport.start/1` when you need streaming IO,
subscriber delivery, and transport metadata:

```elixir
ref = make_ref()

{:ok, transport} =
  Transport.start(
    command: Command.new("sh", ["-c", "cat"]),
    subscriber: {self(), ref},
    stdout_mode: :raw,
    stdin_mode: :raw
  )

:ok = Transport.send(transport, "alpha")
:ok = Transport.end_input(transport)
```

Tagged subscribers receive:

- `{event_tag, ref, {:message, line}}`
- `{event_tag, ref, {:data, chunk}}`
- `{event_tag, ref, {:stderr, chunk}}`
- `{event_tag, ref, {:error, %ExternalRuntimeTransport.Transport.Error{}}}`
- `{event_tag, ref, {:exit, %ExternalRuntimeTransport.ProcessExit{}}}`

## Public Placement Seam

Execution Plane is now the architecture owner of this placement seam. The shell
here preserves the same historical shape:

- `contract_version`
- `surface_kind`
- `transport_options`
- `target_id`
- `lease_ref`
- `surface_ref`
- `boundary_class`
- `observability`

It does not carry adapter module names.

`ExternalRuntimeTransport.ExecutionSurface.to_map/1` projects the struct form
into the versioned map form for boundary exchange.

Built-in surfaces today are:

- `:local_subprocess`
- `:ssh_exec`
- `:guest_bridge`

They remain callable here as compatibility vocabulary, but the active owner is
`execution_plane`.

## Capability Helpers

Use the execution-surface helpers when higher layers need generic reasoning:

```elixir
alias ExternalRuntimeTransport.ExecutionSurface

ExecutionSurface.remote_surface?(surface_kind: :ssh_exec)
ExecutionSurface.path_semantics(surface_kind: :guest_bridge)
ExecutionSurface.nonlocal_path_surface?(surface_kind: :guest_bridge)
```
## Oversize Stdout And Stderr Frames

The default line-handling posture is now:

- steady-state buffer: `max_buffer_size = 1_048_576`
- chunk window: `oversize_line_chunk_bytes = 131_072`
- recoverable line ceiling: `max_recoverable_line_bytes = 16_777_216`
- hard-failure posture: `oversize_line_mode = :chunk_then_fail`

That default lets the transport recover legitimate multi-megabyte single lines without silently
dropping bytes, while still treating genuinely unbounded output as a fatal contract violation.

If you raise any of these limits, raise them coherently. `max_recoverable_line_bytes` must stay at
or above `max_buffer_size`, and the chunk window must stay at or below the recoverable ceiling.
