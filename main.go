package main

import (
	"github.com/sqlc-dev/plugin-sdk-go/codegen"

	zig "github.com/tinyzimmer/sqlc-gen-zig/internal"
)

func main() {
	codegen.Run(zig.Generate)
}
