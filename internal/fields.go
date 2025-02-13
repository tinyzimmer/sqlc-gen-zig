package zig

import (
	"fmt"
	"strings"

	"github.com/sqlc-dev/plugin-sdk-go/plugin"
)

type Field struct {
	Name     string
	Comment  string
	ZigType  string
	Nullable bool
	Array    bool
	Index    int
	Enum     bool
}

func (f Field) ZigID() string {
	if f.Enum {
		return "models." + f.ZigType
	}
	return f.ZigType
}

func buildFields(_ Config, req *plugin.GenerateRequest, columns []*plugin.Column) []Field {
	var fields []Field
	for idx, column := range columns {
		name := column.GetName()
		if name == "" {
			name = fmt.Sprintf("column_%d", idx)
		}
		zigType, isEnum := zigDataType(req, column)
		fields = append(fields, Field{
			Name:     name,
			Comment:  column.GetComment(),
			ZigType:  zigType,
			Nullable: !column.GetNotNull(),
			Array:    column.GetIsArray(),
			Index:    idx,
			Enum:     isEnum,
		})
	}
	return fields
}

func zigDataType(req *plugin.GenerateRequest, column *plugin.Column) (typeName string, isEnum bool) {
	dbType := dbDataType(column.GetType())
	switch req.GetSettings().GetEngine() {
	case "postgresql":
		if pgType := postgresqlType(dbType); pgType != "" {
			return pgType, false
		}
		if enumType := enumType(req.GetCatalog(), dbType); enumType != "" {
			return enumType, true
		}
		panic(fmt.Errorf("unsupported postgresql type: %s", dbType))
	case "sqlite":
		return sqliteType(dbType), false
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
	switch strings.ToLower(dbType) {
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
		return "[]const u8"
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

func sqliteType(dbType string) string {
	spl := strings.Split(strings.ToLower(dbType), ".")
	baseType := spl[len(spl)-1]
	// Hack to handle parameterized types
	if strings.Contains(baseType, "(") {
		baseType = strings.Split(baseType, "(")[0]
	}
	switch baseType {
	case "tinyint":
		return "i64"
	case "smallint", "int2":
		return "i64"
	case "mediumint":
		return "i64"
	case "int", "integer", "bigint", "int8":
		return "i64"
	case "real", "double", "double precision", "float", "numeric", "decimal":
		return "f64"
	case "text", "character", "varchar", "varying character", "nchar", "native character", "nvarchar", "clob":
		return "[]const u8"
	case "blob":
		return "zqlite.Blob"
	case "boolean":
		return "bool"
	case "date", "datetime", "timestamp", "time":
		return "i64"
	default:
		// Assume it can be treated as a blob
		return "zqlite.Blob"
	}
}
