# Guest Bridge Contract

`:guest_bridge` is the built-in execution surface for attached guest runtimes
that expose the shared bridge protocol instead of a raw spawn boundary.

## When To Use It

Use `:guest_bridge` when the command runs inside an already-available guest
runtime and the guest can expose the transport bridge protocol.

Do not use it to model generic lease allocation or workspace policy. Those
concerns stay above the transport layer.

## Transport Options

`transport_options` for `:guest_bridge` are:

- `endpoint`
- `bridge_ref`
- `attach_token`
- `bridge_profile`
- `supported_protocol_versions`
- `extensions`
- `connect_timeout_ms`
- `request_timeout_ms`

`endpoint` can be:

- `%{kind: :unix_socket, path: "/path/to/socket"}`
- `%{kind: :tcp, host: "127.0.0.1", port: 40_321}`

## Attach Negotiation

The adapter negotiates:

- protocol version
- bridge profile
- effective capabilities
- adapter metadata such as the negotiated bridge session reference

The resulting metadata is exposed through `ExternalRuntimeTransport.Transport.Info`.

## Path Semantics

`:guest_bridge` reports:

- `remote?: true`
- `path_semantics: :guest`

That distinction matters. The transport crosses a remote boundary, but command
lookup and PATH behavior belong to the guest runtime rather than to a generic
SSH-style remote shell.

Higher layers should use `path_semantics` when deciding how to explain CLI
resolution failures.
