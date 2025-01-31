# sqlc-gen-zig

A Zig code generator for [sqlc](https://sqlc.dev/).

## Usage

Head over to the [releases](https://github.com/tinyzimmer/sqlc-gen-zig/releases/latest) for instructions on how to configure your `sqlc.yaml`.
An example project can be found in the [examples/](examples/) directory.

### Configuration

The fields below are available as `options` in your `sqlc.yaml`.

```yaml
# The Zig backend to use (currently only "pg.zig" is supported)
backend: pg.zig
# Set to true to create structs with the singular table name
emit_exact_table_names: false
# Exclude the following table names from being parsed into their singular form
inflection_exclude_table_names: []
# The maximum number of query parameters before creating a struct to hold them
query_parameter_limit: 3
# Mark the inlined raw query strings as public
public_query_strings: false
```

## Development

The code generator is written in Go and uses the `sqlc-plugin-sdk`.
An end-to-end test can be run with `make e2e`.
