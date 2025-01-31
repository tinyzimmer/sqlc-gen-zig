# sqlc-gen-zig

A Zig code generator for [sqlc](https://sqlc.dev/).

## Usage

Head over to the [releases](https://github.com/tinyzimmer/sqlc-gen-zig/releases/latest) for instructions on how to configure your `sqlc.yaml`.
An example project can be found in the [examples/](examples/) directory.

### Configuration

```yaml
# sqlc.yaml
version: "2"
plugins:
  - name: zig
    wasm:
      url: https://github.com/tinyzimmer/sqlc-gen-zig/releases/download/v0.0.6/sqlc-gen-zig.wasm
      sha256: e56c08768e411a7e8bee58ef8697cef73a37d917f84065248662bad89d1170e7
sql:
  - schema: schema.sql
    queries: queries.sql
    engine: postgresql
    codegen:
      - out: src/models
        plugin: zig
        options: {}
```

Below are the available `options` with their default values:

```yaml
# The Zig backend to use (currently only "pg.zig" is supported)
backend: pg.zig
# Set to true to create structs with the singular table name
emit_exact_table_names: false
# Exclude the following table names from being parsed into their singular form
inflection_exclude_table_names: []
# The maximum number of query parameters before creating a struct to hold them
query_parameter_limit: 3
# Mark the raw query string constants as public
public_query_strings: false
```

## Development

The code generator is written in Go and uses the `sqlc-plugin-sdk`.
An end-to-end test can be run with `make e2e`.
