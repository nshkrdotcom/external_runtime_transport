# Examples

These examples show the public placement seam honestly: callers describe one
`execution_surface`, and `external_runtime_transport` resolves the built-in
adapter internally.

## Included Examples

- `examples/run_over_execution_surface.exs` shows local and SSH command
  execution through the same facade.
## Oversize-Line Validation

This repo keeps the oversize-line hardening lane intentionally close to the transport tests instead
of shipping a noisy live example. The authoritative checks are:

- `test/external_runtime_transport/transport/subprocess_test.exs`
- `test/external_runtime_transport/transport/options_test.exs`

Those tests cover chunk-first recovery, recoverable multi-chunk lines, and fatal structured
overflow reporting once the configured hard ceiling is crossed.
