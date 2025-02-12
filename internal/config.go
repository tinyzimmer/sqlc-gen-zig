package zig

import (
	"fmt"

	"github.com/sqlc-dev/plugin-sdk-go/plugin"
)

const (
	enginePostgres = "postgresql"
	engineSqlite   = "sqlite"
)

type Config struct {
	Backend                     Backend  `json:"backend"`
	EmitExactTableNames         bool     `json:"emit_exact_table_names"`
	InflectionExcludeTableNames []string `json:"inflection_exclude_table_names"`
	QueryParameterLimit         int      `json:"query_parameter_limit"`
	PublicQueryStings           bool     `json:"public_query_strings"`
	UnmanagedAllocations        bool     `json:"unmanaged_allocations"`
	UseContext                  bool     `json:"use_context"`
	PGErrorUnions               bool     `json:"pg_error_unions"`
}

func (c *Config) Default(req *plugin.GenerateRequest) {
	switch req.GetSettings().GetEngine() {
	case enginePostgres:
		c.Backend = PGZigBackend
	case engineSqlite:
		c.Backend = ZqliteBackend
	}
	c.QueryParameterLimit = 3
}

func (c *Config) Validate(req *plugin.GenerateRequest) error {
	if !c.Backend.IsValidFor(req) {
		return fmt.Errorf("invalid backend for %s: %s", req.GetSettings().GetEngine(), c.Backend)
	}
	if c.QueryParameterLimit < 1 {
		return fmt.Errorf("query_parameter_limit must be greater than 0")
	}
	return nil
}

type Backend string

const (
	PGZigBackend  Backend = "pg.zig"
	ZqliteBackend Backend = "zqlite.zig"
)

func (b Backend) IsValidFor(req *plugin.GenerateRequest) bool {
	switch req.GetSettings().GetEngine() {
	case enginePostgres:
		return b == PGZigBackend
	case engineSqlite:
		return b == ZqliteBackend
	default:
		return false
	}
}

func (b Backend) ImportName() string {
	switch b {
	case PGZigBackend:
		return "pg"
	case ZqliteBackend:
		return "zqlite"
	default:
		return ""
	}
}
