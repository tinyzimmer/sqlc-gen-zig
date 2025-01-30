# sqlc-gen-zig

A Zig code generator for [sqlc](https://sqlc.dev/).

## Usage

Head over to the [releases](https://github.com/tinyzimmer/sqlc-gen-zig/releases/latest) for instructions on how to configure your `sqlc.yaml`.

## Development

The code generator is written in Go and uses the `sqlc-plugin-sdk`.
An end-to-end test can be run with `make e2e`.
The schema for this test can be found in [tests/e2e/](tests/e2e/schema) and the generated code is written to [tests/e2e/src/gen](tests/e2e/src/gen)
Example usage of the generated code can be found in [tests/e2e/src/main.zig](tests/e2e/src/main.zig).
