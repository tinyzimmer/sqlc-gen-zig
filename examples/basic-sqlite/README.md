# Basic `sqlc` Example for Sqlite

This is a basic `sqlc` setup with a single table and queries file.
The schema and queries can be found in the [src/schema/](src/schema/) directory.
Generated code is written to [src/models](src/models) and [src/main.zig](src/main.zig) contains example usage.

## Setup

You must have [sqlc](https://sqlc.dev/) installed to run this example.

```sh
sqlc generate
```

Then to run the code in `src/main.zig`:

```sh
zig build run
```
