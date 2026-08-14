.PHONY: all proto lint proto-breaking fmt rust-build go-build run-rust run-go

all: proto fmt rust-build go-build

proto:
	buf generate

lint:
	buf lint

proto-breaking:
	buf breaking --against '.git#branch=main'

fmt:
	cd bs-ran && cargo fmt
	cd core-services && go fmt ./...

rust-build:
	cd bs-ran && cargo build --workspace

go-build:
	cd core-services && go build ./...

run-rust:
	cd bs-ran && cargo run

run-go:
	cd core-services && go run ./cmd/core
