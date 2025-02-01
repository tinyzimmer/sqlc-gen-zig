# Basic `sqlc` Example

This is a basic `sqlc` setup with a single table and queries file.
The schema and queries can be found in the [schema/](schema/) directory.
Generated code is written to [src/models](src/models) and [src/main.zig](src/main.zig) contains example usage.

## Setup

You must have [sqlc](https://sqlc.dev/) installed to run this example.

```sh
sqlc generate
```

The code depends on a local postgres instance that can be started with the `docker-compose` file.
To start it run:

```sh
docker-compose up -d
```

Then to run the code in `src/main.zig`:

```sh
zig build run
```
