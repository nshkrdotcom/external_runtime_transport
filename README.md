<p align="center">
  <img src="assets/external_runtime_transport.svg" alt="External Runtime Transport logo" width="200" height="200" />
</p>

<h1 align="center">External Runtime Transport</h1>

<p align="center">
  <a href="https://hex.pm/packages/external_runtime_transport"><img src="https://img.shields.io/hexpm/v/external_runtime_transport.svg" alt="Hex version" /></a>
  <a href="https://hexdocs.pm/external_runtime_transport"><img src="https://img.shields.io/badge/hexdocs-docs-264FD7.svg" alt="HexDocs" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-111111.svg" alt="MIT License" /></a>
</p>

`external_runtime_transport` is a focused Elixir library for building and
standardizing transport boundaries between external runtimes, provider-facing
interfaces, and downstream AI SDK layers.

The project starts intentionally small. Its purpose is to provide a clean
foundation for evolving request transport contracts, adapter composition, and
runtime interoperability without dragging application concerns into the core
library.

## Installation

Add `external_runtime_transport` to your dependencies:

```elixir
def deps do
  [
    {:external_runtime_transport, "~> 0.1.0"}
  ]
end
```

## Scope

- Define a small, durable foundation for external runtime transport concerns.
- Keep transport semantics separate from higher-level SDK orchestration.
- Package the project cleanly for Hex and HexDocs distribution.

## Development

```bash
mix deps.get
mix format
mix test
mix docs
```

## Documentation

HexDocs will publish the rendered README, changelog, and license once the
package is released:

<https://hexdocs.pm/external_runtime_transport>
