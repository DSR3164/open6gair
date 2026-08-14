# 0001. Monorepo structure and codegen pipeline

## Status
Accepted

## Context
Open6GAir spans a real-time base station component (`bs-ran`, Rust) and a
control-plane component (`core-services`, Go), sharing a gRPC/protobuf
contract (`proto/`). Contract changes need to land atomically across both
languages in a single PR.

## Decisions

- **Layout**: `bs-ran/` (Rust workspace), `core-services/` (Go module),
  `proto/` (shared contract) as siblings in one repository.
- **Codegen**: unified `buf generate` pipeline drives both Go and Rust stubs
  from the same `.proto` sources, rather than a separate `tonic-build`
  (`build.rs`) step for Rust. Plugins are installed locally
  (`protoc-gen-prost`, `protoc-gen-tonic`, `protoc-gen-go`,
  `protoc-gen-go-grpc`) rather than resolved via BSR remote plugins, for
  offline/version control.
- **Rust generated code**: lives in a dedicated `proto-gen` crate.
  `Cargo.toml` and `lib.rs` are hand-written once; `lib.rs` uses
  `include!()` to pull in files dropped by `buf generate`. Other crates
  depend on `proto-gen` as a normal workspace path dependency.
- **Go generated code**: plain packages under `core-services/gen/go`,
  imported by path — no special registration needed.
- **Cargo.lock**: committed. `bs-ran` is an application workspace (produces
  a deployable binary for base station nodes), not a published library, so
  reproducible builds take priority over downstream resolution flexibility.
- **Generated code in git**: not committed (`gen/go/`,
  `proto-gen/src/open6gair/`). Regenerated via `make proto` after clone
  or after editing `.proto` files.

## Verified codegen output (open6gair.v1 / HealthService)

The two open questions above are resolved by direct inspection of
`buf generate` output for the first real `.proto`
(`proto/open6gair/v1/health.proto`):

- **File layout**: `protoc-gen-prost` and `protoc-gen-tonic` write into
  `bs-ran/crates/proto-gen/src/open6gair/v1/` (nested by package path, not
  flat in `src/`), producing two files:
  - `open6gair.v1.rs` — message/enum types (protoc-gen-prost)
  - `open6gair.v1.tonic.rs` — gRPC client/server stubs (protoc-gen-tonic)
- **Cross-file linking**: `open6gair.v1.rs` itself contains
  `include!("open6gair.v1.tonic.rs");` at the end — protoc-gen-prost
  automatically pulls in the tonic file when a service is defined for the
  same package. `proto-gen/src/lib.rs` must therefore `include!()` only
  the prost file, not both — including the tonic file a second time causes
  duplicate module definitions (`E0428`).
- **`protoc-gen-prost-crate`**: not needed. A hand-written `Cargo.toml` +
  `lib.rs` with a single `include!()` is sufficient.
- **RPC naming**: buf's `STANDARD` lint ruleset
  (`RPC_REQUEST_STANDARD_NAME` / `RPC_RESPONSE_STANDARD_NAME`) requires
  request/response types to be named `<Method>Request`/`<Method>Response`
  or `<Service><Method>Request`/`<Service><Method>Response`. The project
  uses the latter form (e.g. `HealthServiceCheckRequest`, not
  `HealthCheckRequest`).
- **Version pinning is load-bearing**: `protoc-gen-tonic 0.5.0` generates
  code against the `tonic 0.14` API (`tonic_prost::ProstCodec`,
  `tonic::body::Body`), which does not exist in `tonic 0.12`/`0.13`.
  `workspace.dependencies` must pin `tonic = "0.14"`,
  `tonic-prost = "0.14"`, `prost = "0.14"` together — `tonic 0.13` +
  `prost 0.14` is a known-broken combination upstream (mismatched macro
  codegen paths), so these three must move as a set, not independently.