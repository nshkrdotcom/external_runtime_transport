<p align="center">
  <img src="assets/external_runtime_transport.svg" alt="External Runtime Transport logo" width="200" height="200" />
</p>

# ExternalRuntimeTransport

<p align="center">
  <a href="https://hex.pm/packages/external_runtime_transport"><img src="https://img.shields.io/hexpm/v/external_runtime_transport.svg" alt="Hex version" /></a>
  <a href="https://hexdocs.pm/external_runtime_transport"><img src="https://img.shields.io/badge/hexdocs-docs-264FD7.svg" alt="HexDocs" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-111111.svg" alt="MIT License" /></a>
</p>

`external_runtime_transport` is the shared execution-surface substrate for the
Jido runtime stack. It owns the generic `execution_surface` contract, adapter
registry, transport facade, and the built-in `:local_subprocess`,
`:ssh_exec`, and `:guest_bridge` families.

The package is intentionally transport-focused. Provider planning, session
parsing, approval policy, workspace policy, and other application concerns stay
in downstream repos such as `cli_subprocess_core`.

## What This Package Owns

- `ExternalRuntimeTransport.ExecutionSurface` defines the public placement seam.
- `ExternalRuntimeTransport.Transport` is the generic run/start facade.
- `ExternalRuntimeTransport.ExecutionSurface.Adapter` and the internal registry
  own built-in adapter dispatch.
- the built-in local subprocess, SSH exec, and guest bridge adapters implement
  the landed transport families.
- `ExternalRuntimeTransport.Transport.Options`,
  `ExternalRuntimeTransport.Transport.RunOptions`,
  `ExternalRuntimeTransport.Transport.RunResult`, and
  `ExternalRuntimeTransport.Transport.Info` own normalized transport contracts.
- `ExternalRuntimeTransport.Command`, `ExternalRuntimeTransport.ProcessExit`,
  `ExternalRuntimeTransport.LineFraming`, and `ExternalRuntimeTransport.TaskSupport`
  support the substrate itself.

## Installation

```elixir
def deps do
  [
    {:external_runtime_transport, "~> 0.1.0"}
  ]
end
```

## Quick Start

Run a local command through the generic facade:

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

The public placement contract is one `execution_surface` value with these
fields:

- `surface_kind`
- `transport_options`
- `target_id`
- `lease_ref`
- `surface_ref`
- `boundary_class`
- `observability`

The contract does not expose adapter module names. Callers choose placement by
describing the surface, and the substrate resolves the built-in adapter
internally.

Supported built-in surface kinds today are:

- `:local_subprocess`
- `:ssh_exec`
- `:guest_bridge`

Use `ExternalRuntimeTransport.ExecutionSurface.capabilities/1`,
`path_semantics/1`, `remote_surface?/1`, and `nonlocal_path_surface?/1` when a
higher layer needs to reason about the surface generically.

## Documentation

- `guides/getting-started.md` covers the public facade.
- `guides/execution-surface-contract.md` defines the stable placement seam.
- `guides/guest-bridge-contract.md` covers the attach contract for
  `:guest_bridge`.
- `examples/README.md` points at runnable placement examples.

Published HexDocs:

<https://hexdocs.pm/external_runtime_transport>
