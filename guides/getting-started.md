# Getting Started

`external_runtime_transport` gives downstream runtimes one place to express
process placement without leaking adapter module names into public APIs.

## Install

```elixir
def deps do
  [
    {:external_runtime_transport, "~> 0.1.0"}
  ]
end
```

## One-Shot Commands

Use `ExternalRuntimeTransport.Transport.run/2` with a normalized
`ExternalRuntimeTransport.Command`:

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

Every public placement call stays on one `execution_surface` seam. It carries:

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
