# sqlc-gen-zig

A Zig code generator for [sqlc](https://sqlc.dev/).

## Usage

Head over to the [releases](https://github.com/tinyzimmer/sqlc-gen-zig/releases/latest) for instructions on how to configure your `sqlc.yaml`.
Example projects can be found in the [examples/](examples/) directory.

### Configuration

```yaml
# sqlc.yaml
version: "2"
plugins:
  - name: zig
    wasm:
      url: https://github.com/tinyzimmer/sqlc-gen-zig/releases/download/v0.0.11/sqlc-gen-zig.wasm
      sha256: 12f9a43c0223c6da64b623691b5264b5827f7acfca23674a1cbfd0494c845f61
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
# e2e/src/context.zig tests for some examples for now.
use_context: false
# Set to true to return a union of pg.Error and the query result instead of
# returning just the result. This is useful for code that wants to handle server
# side errors in a more granular way (e.g. checking for constraint violations).
# As with context for now, see the tests in e2e/src/unions.zig for examples.
pg_error_unions: false
```

## Development

The code generator is written in Go and uses the `sqlc-plugin-sdk`.
The end-to-end tests can be run with `make e2e`.
