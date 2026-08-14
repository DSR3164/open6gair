# Open6GAir

Open-source 6G base station stack: real-time RAN in Rust, control plane in Go,
shared gRPC contract in protobuf.

## Structure

- `bs-ran/` — Rust workspace. Real-time base station (PHY/L2/control).
  `unsafe` is confined to a dedicated eBPF/hardware-facing layer; the rest
  is safe Rust.
- `core-services/` — Go module. Control plane, session management, OAM.
- `proto/` — shared gRPC/protobuf contract consumed by both sides.
- `docs/architecture/` — ADRs recording structural decisions.

## Codegen

Protobuf/gRPC stubs for both languages are generated from `proto/` via
[buf](https://buf.build):

```bash
make proto  # regenerate Go + Rust stubs
make lint   # lint .proto files
```

Requires local plugins:

```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
cargo install protoc-gen-prost protoc-gen-tonic
```

**Version note**: `protoc-gen-tonic 0.5.0` generates code against the
`tonic 0.14` API. Keep `tonic`, `tonic-prost`, and `prost` on matching
`0.14.x` versions in `bs-ran/Cargo.toml` — mismatched versions fail with
errors like `cannot find tonic_prost` or `cannot find type Body`.

Generated code is not committed; regenerate after clone or after editing
any `.proto` file.

See [`docs/architecture/0001-monorepo-structure.md`](docs/architecture/0001-monorepo-structure.md)
for the full rationale.

## Build

```bash
make
```
