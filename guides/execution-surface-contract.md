# Execution Surface Contract

`ExternalRuntimeTransport.ExecutionSurface` is the stable placement seam shared
across the runtime stack.

## Fields

An execution surface carries:

- `surface_kind`
- `transport_options`
- `target_id`
- `lease_ref`
- `surface_ref`
- `boundary_class`
- `observability`

These fields are intentionally generic. They describe where a command should
run and how the transport should attach, but they do not leak provider or
application policy.

## What Does Not Belong Here

Do not put these concerns into `execution_surface`:

- adapter module names
- command or args
- cwd, env, or user launch fields
- workspace policy
- approval policy
- provider feature flags

Those concerns belong in the transport invocation or in higher runtime layers.

## Built-In Surface Kinds

The landed built-in kinds are:

- `:local_subprocess`
- `:ssh_exec`
- `:guest_bridge`

The registry is package-owned. Public callers choose among the landed kinds but
do not register adapters directly.

## Capability Vocabulary

Each built-in adapter reports normalized capabilities through
`ExternalRuntimeTransport.ExecutionSurface.Capabilities`.

The important fields are:

- `remote?`
- `startup_kind`
- `path_semantics`
- `supports_run?`
- `supports_streaming_stdio?`
- `supports_pty?`
- `supports_user?`
- `supports_env?`
- `supports_cwd?`
- `interrupt_kind`

Use these helpers instead of branching on adapter modules:

- `ExecutionSurface.capabilities/1`
- `ExecutionSurface.path_semantics/1`
- `ExecutionSurface.remote_surface?/1`
- `ExecutionSurface.nonlocal_path_surface?/1`

## Resolution Flow

The public dispatch flow is:

1. caller authors `execution_surface`
2. `ExecutionSurface.resolve/1` validates and normalizes the surface
3. `ExternalRuntimeTransport.Transport` enforces generic capability rules
4. the resolved built-in adapter runs the family-specific logic

That keeps the public seam stable even as the underlying adapter family
changes.
