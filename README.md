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
      url: https://github.com/tinyzimmer/sqlc-gen-zig/releases/download/v0.0.7/sqlc-gen-zig.wasm
      sha256: 9752fb1a2f1143780204adf8d53ef6ec1ac700563b3dc07a96dfa8bb0f9b8990
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
# Set to true to not force struct names to their singular form
emit_exact_table_names: false
# Exclude the following table names from being parsed into their singular form
inflection_exclude_table_names: []
# The maximum number of query parameters before creating a struct to hold them
query_parameter_limit: 3
# Mark the raw query string constants as public
public_query_strings: false
# Set to true to not have the Querier store an internal allocator. Each query
# method will take an allocator as a parameter instead.
unmanaged_allocations: false
# Use context as parameters to generated methods. This is useful for code that
# wants to execute queries with zero additional allocations. Context is a struct
# with a `handle` method taking the return value of the query method. See the
# e2e tests for more examples for now.
use_context: false
```

## Development

The code generator is written in Go and uses the `sqlc-plugin-sdk`.
An end-to-end test can be run with `make e2e`.
