package zig

import (
	"fmt"

	"github.com/sqlc-dev/plugin-sdk-go/plugin"
)

type Field struct {
	Name     string
	Comment  string
	ZigType  string
	Nullable bool
	Array    bool
}

func buildFields(_ Config, req *plugin.GenerateRequest, columns []*plugin.Column) []Field {
	var fields []Field
	for _, column := range columns {
		fields = append(fields, Field{
			Name:     column.GetName(),
			Comment:  column.GetComment(),
			ZigType:  zigDataType(req, column),
			Nullable: !column.GetNotNull(),
			Array:    column.GetIsArray(),
		})
	}
	return fields
}

func zigDataType(req *plugin.GenerateRequest, column *plugin.Column) string {
	dbType := dbDataType(column.GetType())
	switch req.GetSettings().GetEngine() {
	case "postgresql":
		if pgType := postgresqlType(dbType); pgType != "" {
			return pgType
		}
		if enumType := enumType(req.GetCatalog(), dbType); enumType != "" {
			return enumType
		}
		panic(fmt.Errorf("unsupported postgresql type: %s", dbType))
	default:
		panic(fmt.Errorf("unsupported zig engine: %s", req.GetSettings().GetEngine()))
	}
}

func dbDataType(id *plugin.Identifier) string {
	if id.GetSchema() == "" {
		return id.GetName()
	}
	return fmt.Sprintf("%s.%s", id.GetSchema(), id.GetName())
}

func postgresqlType(dbType string) string {
	switch dbType {
	case "serial", "serial4", "pg_catalog.serial":
		return "i32"
	case "bigserial", "serial8", "pg_catalog.serial8":
		return "i64"
	case "smallserial", "serial2", "pg_catalog.serial2":
		return "i16"
	case "integer", "int", "int4", "pg_catalog.int4":
		return "i32"
	case "bigint", "int8", "pg_catalog.int8":
		return "i64"
	case "smallint", "int2", "pg_catalog.int2":
		return "i16"
	case "float", "double precision", "float8", "pg_catalog.float8":
		return "f64"
	case "real", "float4", "pg_catalog.float4":
		return "f32"
	case "numeric", "pg_catalog.numeric":
		return "pg.Numeric"
	case "money":
		return "f64" // TODO: Implement Money type
	case "boolean", "bool", "pg_catalog.bool":
		return "bool"
	case "json", "jsonb":
		return "std.json.Token"
	case "bytea", "blob", "pg_catalog.bytea":
		return "[]u8"
	case "date":
		return "i64"
	case "pg_catalog.time", "pg_catalog.timetz":
		return "i64"
	case "pg_catalog.timestamp", "pg_catalog.timestamptz", "timestamptz":
		return "i64"
	case "interval", "pg_catalog.interval":
		return "i64"
	case "text", "pg_catalog.varchar", "pg_catalog.bpchar", "string", "citext":
		return "[]const u8"
	case "uuid":
		return "[16]u8"
	case "inet", "cidr":
		return "pg.Cidr"
	case "macaddr", "macaddr8":
		return "[]u8"
	case "ltree", "lquery", "ltxtquery":
		return "[]const u8"
	default:
		return ""
	}
}
