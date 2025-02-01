package zig

import "fmt"

type Config struct {
	Backend                     Backend  `json:"backend"`
	EmitExactTableNames         bool     `json:"emit_exact_table_names"`
	InflectionExcludeTableNames []string `json:"inflection_exclude_table_names"`
	QueryParameterLimit         int      `json:"query_parameter_limit"`
	PublicQueryStings           bool     `json:"public_query_strings"`
	UnmanagedAllocations        bool     `json:"unmanaged_allocations"`
	UseContext                  bool     `json:"use_context"`
}

func (c *Config) Default() {
	c.Backend = PGZigBackend
	c.QueryParameterLimit = 3
}

func (c *Config) Validate() error {
	if !c.Backend.IsValid() {
		return fmt.Errorf("invalid backend: %s", c.Backend)
	}
	if c.QueryParameterLimit < 1 {
		return fmt.Errorf("query_parameter_limit must be greater than 0")
	}
	return nil
}

type Backend string

const (
	PGZigBackend Backend = "pg.zig"
)

func (b Backend) IsValid() bool {
	switch b {
	case PGZigBackend:
		return true
	default:
		return false
	}
}

func (b Backend) ImportName() string {
	switch b {
	case PGZigBackend:
		return "pg"
	default:
		return ""
	}
}
