<p align="center">
  <img src="assets/external_runtime_transport.svg" alt="External Runtime Transport logo" width="200" height="200" />
</p>

# ExternalRuntimeTransport

<p align="center">
  <a href="https://hex.pm/packages/external_runtime_transport"><img src="https://img.shields.io/hexpm/v/external_runtime_transport.svg" alt="Hex version" /></a>
  <a href="https://hexdocs.pm/external_runtime_transport"><img src="https://img.shields.io/badge/hexdocs-docs-264FD7.svg" alt="HexDocs" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-111111.svg" alt="MIT License" /></a>
</p>

`external_runtime_transport` is a deprecation shell for the parts of the lower
runtime substrate that moved into Execution Plane during Waves 2, 6, and 7.

Execution Plane now owns the execution_surface contract, the minimal local
one-shot process substrate, the long-lived transport substrate, and the active
local, SSH, and guest placement implementations for the Brain / Spine /
Execution Plane architecture. This repo remains in place only for
compatibility with already-published APIs.

That includes the minimal local one-shot process substrate that Wave 2 moved
out of this repo.

New lower-runtime adoption should start in `/home/home/p/g/n/execution_plane`,
not here.

## What This Package Still Provides

- the legacy `ExternalRuntimeTransport.Transport` facade for existing callers
- compatibility structs and helper functions that map onto Execution Plane
- compatibility docs for callers that have not yet moved to `execution_plane`
- historical compatibility docs for callers that have not yet adopted `execution_plane`

The `ExternalRuntimeTransport.ExecutionSurface`, `Command`, `ProcessExit`, and
local one-shot `Transport.run/2` vocabulary are now legacy compatibility
surfaces. They remain callable here, but they are no longer the architecture
owner for any active lower-runtime slice.

## Installation

Existing integrations can keep this dependency during migration. New lower
runtime work should depend on `execution_plane` instead.

## Quick Start

Run a local command through the generic facade only when you are staying on the
legacy compatibility surface:

```elixir
alias ExternalRuntimeTransport.Command
alias ExternalRuntimeTransport.Transport

{:ok, result} =
  Transport.run(
    Command.new("sh", ["-c", "printf ready"])
  )

IO.inspect(result.stdout)
```

Move the same command onto SSH without naming an adapter module:

```elixir
{:ok, result} =
  Transport.run(
    Command.new("hostname"),
    execution_surface: [
      surface_kind: :ssh_exec,
      transport_options: [
        destination: "buildbox.example",
        ssh_user: "deploy",
        port: 22
      ]
    ]
  )
```

Start a long-lived transport with the same public seam:

```elixir
ref = make_ref()

{:ok, transport} =
  Transport.start(
    command: Command.new("sh", ["-c", "cat"]),
    subscriber: {self(), ref},
    stdout_mode: :raw,
    stdin_mode: :raw,
    execution_surface: [surface_kind: :local_subprocess]
  )
```

## Execution Surface

Execution Plane now owns the authoritative `execution_surface` contract. This
repo keeps the historical shape below so existing callers do not break while
they migrate:

- `contract_version`
- `surface_kind`
- `transport_options`
- `target_id`
- `lease_ref`
- `surface_ref`
- `boundary_class`
- `observability`

The contract still does not expose adapter module names. Callers choose
placement by describing the surface, and the substrate resolves the built-in
adapter internally.

Use `ExternalRuntimeTransport.ExecutionSurface.to_map/1` when you need the
versioned map projection for JSON-safe boundaries.

Supported built-in surface kinds today are:

- `:local_subprocess`
- `:ssh_exec`
- `:guest_bridge`

Use `ExternalRuntimeTransport.ExecutionSurface.capabilities/1`,
`path_semantics/1`, `remote_surface?/1`, and `nonlocal_path_surface?/1` when a
higher layer needs to reason about the surface generically.

Those values are compatibility projections over the lower Execution Plane
surface. They do not imply this repo still owns the active placement logic.

## Documentation

- `guides/getting-started.md` explains the archival compatibility facade and
  points new adoption to Execution Plane.
- `guides/execution-surface-contract.md` records the legacy placement seam now
  owned by Execution Plane.
- `guides/guest-bridge-contract.md` covers the attach contract for
  `:guest_bridge`.
- `examples/README.md` points at runnable placement examples.

Published HexDocs:

<https://hexdocs.pm/external_runtime_transport>
## Oversize Line Recovery

The transport now treats oversized stdout lines as a bounded recovery problem instead of an
unbounded buffer-growth bug.

- `max_buffer_size` remains the steady-state in-memory line buffer and defaults to `1_048_576`
  bytes.
- `oversize_line_chunk_bytes` defaults to `131_072` bytes and is used to incrementally recover a
  large line without letting the framer grow without bound.
- `max_recoverable_line_bytes` defaults to `16_777_216` bytes and is the hard ceiling for a single
  recoverable line.
- `oversize_line_mode` is now `:chunk_then_fail` and `buffer_overflow_mode` is intentionally
  `:fatal`.

The operational rule is simple: recover the full line while it remains within the configured
ceiling, then fail fast with a structured `buffer_overflow` error once the data-loss boundary is
crossed. The transport no longer pretends that silently dropped bytes are a healthy recovery path.
