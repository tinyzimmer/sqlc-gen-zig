package zig

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"

	"github.com/sqlc-dev/plugin-sdk-go/metadata"
	"github.com/sqlc-dev/plugin-sdk-go/plugin"
)

func engineTemplateFuncs(t *template.Template, req *plugin.GenerateRequest) template.FuncMap {
	switch req.GetSettings().GetEngine() {
	case enginePostgres:
		return postgresqlTemplateFuncs(t)
	case engineSqlite:
		return sqliteTemplateFuncs(t)
	default:
		return template.FuncMap{}
	}
}

func commonTemplateFuncs(t *template.Template) template.FuncMap {
	return template.FuncMap{
		"include": func(name string, data interface{}) (string, error) {
			buf := bytes.NewBuffer(nil)
			if err := t.ExecuteTemplate(buf, name, data); err != nil {
				return "", err
			}
			return buf.String(), nil
		},
		"indent": func(indent int, s string) string {
			pad := strings.Repeat(" ", indent)
			var out strings.Builder
			lines := strings.Split(s, "\n")
			for i, line := range lines {
				if strings.TrimSpace(line) != "" {
					out.WriteString(pad + line)
				}
				if i != len(lines)-1 {
					out.WriteString("\n")
				}
			}
			return out.String()
		},
		"hasNonScalarFields": func(s Struct) bool {
			return hasNonScalarFields(s)
		},
		"multilineStringLiteral": func(s string, indent int) string {
			var out strings.Builder
			lines := strings.Split(s, "\n")
			for i, line := range lines {
				if i != 0 {
					out.WriteString(strings.Repeat(" ", indent))
				}
				out.WriteString("\\\\" + line)
				if i != len(lines)-1 {
					out.WriteString("\n")
				}
			}
			return out.String()
		},
		"queryReturnType": func(q Query) string {
			if q.Ret == nil {
				return "void"
			}
			if q.Ret.Struct != nil {
				if q.Ret.Emit {
					return q.Ret.Struct.StructName
				}
				return fmt.Sprintf("models.%s", q.Ret.Struct.StructName)
			}
			return fmt.Sprintf("%s", q.Ret.Field.ZigID())
		},
		"errorUnionType": func(q Query) string {
			return pascalCase(fmt.Sprintf("%sResult", q.MethodName))
		},
		"queryReturnID": func(conf Config, q Query) string {
			if q.Ret == nil {
				return "ok"
			}
			var val string
			if q.Ret.Struct != nil {
				val = snakeCase(q.Ret.Struct.StructName)
			} else {
				val = snakeCase(q.Ret.Field.Name)
			}
			if q.Cmd == metadata.CmdMany && !conf.UseContext {
				return fmt.Sprintf("%s_list", val)
			}
			return val
		},
		"hasLocalStructArg": func(q Query) bool {
			for _, arg := range q.Args {
				if arg.Struct != nil {
					return true
				}
			}
			return false
		},
		"isOneQuery": func(q Query) bool {
			return q.Cmd == metadata.CmdOne
		},
		"isManyQuery": func(q Query) bool {
			return q.Cmd == metadata.CmdMany
		},
		"isExecQuery": func(q Query) bool {
			return q.Cmd == metadata.CmdExec
		},
		"isNonScalar": func(field Field) bool {
			return isNonScalarBaseType(field)
		},
		"allocType": func(field Field) string {
			if field.ZigType == "zqlite.Blob" {
				return "u8"
			}
			baseType := strings.TrimPrefix(field.ZigType, "[]")
			baseType = strings.TrimPrefix(baseType, "const ")
			return baseType
		},
		"snakeCase": func(s string) string {
			return snakeCase(s)
		},
		"pascalCase": func(s string) string {
			return pascalCase(s)
		},
		"queryWithConfig": func(conf Config, q Query) map[string]any {
			return map[string]any{
				"Config": conf,
				"Query":  q,
			}
		},
	}
}

func postgresqlTemplateFuncs(_ *template.Template) template.FuncMap {
	return template.FuncMap{
		"hasPgTypes": func(models []Struct) bool {
			for _, model := range models {
				for _, field := range model.Fields {
					if strings.HasPrefix(field.ZigType, "pg.") {
						return true
					}
				}
			}
			return false
		},
		"hasEnums": func(models []Struct) bool {
			for _, model := range models {
				for _, field := range model.Fields {
					if field.Enum {
						return true
					}
				}
			}
			return false
		},
		"hasEnumArrayArgs": func(query Query) bool {
			for _, arg := range query.Args {
				if arg.Struct != nil {
					for _, field := range arg.Struct.Fields {
						if field.Enum && field.Array {
							return true
						}
					}
				} else {
					if arg.Field.Enum && arg.Field.Array {
						return true
					}
				}
			}
			return false
		},
		"callQueryFunc": func(q Query) string {
			if q.Cmd == metadata.CmdExec {
				return "conn.exec"
			}
			return "conn.query"
		},
		"fieldScanType": func(f Field) string {
			if f.Nullable {
				return fmt.Sprintf("?%s", f.ZigID())
			}
			return f.ZigID()
		},
		"queryFuncArgs": func(conf Config, q Query) string {
			var out strings.Builder
			out.WriteString("self: Self")
			if conf.UnmanagedAllocations && !conf.UseContext {
				if q.RequiresAllocations() {
					out.WriteString(", allocator: Allocator")
				}
			}
			if conf.UseContext && (conf.PGErrorUnions || q.Cmd != metadata.CmdExec) {
				out.WriteString(", ctx: anytype")
			}
			for i, name := range q.ArgNames() {
				arg := q.Args[i]
				out.WriteString(", ")
				if arg.Struct != nil {
					out.WriteString(fmt.Sprintf("%s: %s", name, arg.Struct.StructName))
				} else {
					switch arg.Field.ZigType {
					case "pg.Numeric":
						out.WriteString(fmt.Sprintf("%s: f64", name))
					case "pg.Cidr":
						out.WriteString(fmt.Sprintf("%s: []const u8", name))
					default:
						out.WriteString(fmt.Sprintf("%s: %s", name, arg.Field.ZigID()))
					}
				}
			}
			return out.String()
		},
		"queryExecParams": func(q Query, indent int) string {
			var out strings.Builder
			out.WriteString(".{")
			indentSpace := strings.Repeat(" ", indent)
			endIndent := strings.Repeat(" ", indent-4)
			for i, name := range q.ArgNames() {
				arg := q.Args[i]
				if i != 0 {
					out.WriteString(indentSpace)
				} else {
					out.WriteString(" \n")
					out.WriteString(indentSpace)
				}
				if arg.Struct != nil {
					for i, field := range arg.Struct.Fields {
						if i != 0 {
							out.WriteString(fmt.Sprintf(",\n%s", strings.Repeat(" ", indent)))
						}
						out.WriteString(fmt.Sprintf("%s.%s", name, field.Name))
					}
				} else {
					out.WriteString(name)
				}
				out.WriteString(",\n")
				if i == len(q.Args)-1 {
					out.WriteString(endIndent)
				}
			}
			out.WriteString("}")
			return out.String()
		},
	}
}

func sqliteTemplateFuncs(_ *template.Template) template.FuncMap {
	return template.FuncMap{
		"isBlob": func(f Field) bool {
			return f.ZigType == "zqlite.Blob"
		},
		"callQueryFunc": func(q Query) string {
			if q.Cmd == metadata.CmdExec {
				return "conn.exec"
			}
			return "conn.rows"
		},
		"fieldScanner": func(f Field) string {
			if f.Nullable {
				switch f.ZigType {
				case "i64":
					return "nullableInt"
				case "f64":
					return "nullableFloat"
				case "bool":
					return "nullableBoolean"
				case "[]const u8":
					return "nullableText"
				default:
					return "nullableBlob"
				}
			} else {
				switch f.ZigType {
				case "i64":
					return "int"
				case "f64":
					return "float"
				case "bool":
					return "boolean"
				case "[]const u8":
					return "text"
				default:
					return "blob"
				}
			}
		},
		"queryFuncArgs": func(conf Config, q Query) string {
			var out strings.Builder
			out.WriteString("self: Self")
			if conf.UnmanagedAllocations && !conf.UseContext {
				if q.RequiresAllocations() {
					out.WriteString(", allocator: Allocator")
				}
			}
			if conf.UseContext && (conf.PGErrorUnions || q.Cmd != metadata.CmdExec) {
				out.WriteString(", ctx: anytype")
			}
			for i, name := range q.ArgNames() {
				arg := q.Args[i]
				out.WriteString(", ")
				if arg.Struct != nil {
					out.WriteString(fmt.Sprintf("%s: %s", name, arg.Struct.StructName))
				} else {
					switch arg.Field.ZigType {
					case "zqlite.Blob":
						out.WriteString(fmt.Sprintf("%s: []const u8", name))
					default:
						out.WriteString(fmt.Sprintf("%s: %s", name, arg.Field.ZigID()))
					}
				}
			}
			return out.String()
		},
		"queryExecParams": func(q Query, indent int) string {
			var out strings.Builder
			out.WriteString(".{")
			indentSpace := strings.Repeat(" ", indent)
			endIndent := strings.Repeat(" ", indent-4)
			for i, name := range q.ArgNames() {
				arg := q.Args[i]
				if i != 0 {
					out.WriteString(indentSpace)
				} else {
					out.WriteString(" \n")
					out.WriteString(indentSpace)
				}
				if arg.Struct != nil {
					for i, field := range arg.Struct.Fields {
						if i != 0 {
							out.WriteString(fmt.Sprintf(",\n%s", strings.Repeat(" ", indent)))
						}
						if field.ZigType == "zqlite.Blob" {
							out.WriteString(fmt.Sprintf("zqlite.blob(%s.%s)", name, field.Name))
						} else {
							out.WriteString(fmt.Sprintf("%s.%s", name, field.Name))
						}
					}
				} else {
					if arg.Field.ZigType == "zqlite.Blob" {
						out.WriteString(fmt.Sprintf("zqlite.blob(%s)", name))
					} else {
						out.WriteString(name)
					}
				}
				out.WriteString(",\n")
				if i == len(q.Args)-1 {
					out.WriteString(endIndent)
				}
			}
			out.WriteString("}")
			return out.String()
		},
	}
}
