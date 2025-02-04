package zig

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"

	"github.com/sqlc-dev/plugin-sdk-go/metadata"
)

func templateFuncs(t *template.Template) template.FuncMap {
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
			return fmt.Sprintf("%s", q.Ret.Field.ZigType)
		},
		"errorUnionType": func(q Query) string {
			return pascalCase(fmt.Sprintf("%sResult", q.MethodName))
		},
		"queryReturnID": func(q Query) string {
			if q.Ret == nil {
				return "ok"
			}
			if q.Ret.Struct != nil {
				return snakeCase(q.Ret.Struct.StructName)
			}
			return snakeCase(q.Ret.Field.Name)
		},
		"queryFuncArgs": func(conf Config, q Query) string {
			var out strings.Builder
			out.WriteString("self: Self")
			if conf.UnmanagedAllocations && !conf.UseContext {
				if q.RequiresAllocations() {
					out.WriteString(", allocator: Allocator")
				}
			}
			if conf.UseContext && q.Cmd != metadata.CmdExec {
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
						out.WriteString(fmt.Sprintf("%s: %s", name, arg.Field.ZigType))
					}
				}
			}
			return out.String()
		},
		"hasLocalStructArg": func(q Query) bool {
			for _, arg := range q.Args {
				if arg.Struct != nil {
					return true
				}
			}
			return false
		},
		"queryExecParams": func(q Query, indent int) string {
			var out strings.Builder
			for i, name := range q.ArgNames() {
				arg := q.Args[i]
				if i != 0 {
					out.WriteString(strings.Repeat(" ", indent))
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
				if i != len(q.Args)-1 {
					out.WriteString(",\n")
				} else {
					out.WriteString(",")
				}
			}
			return out.String()
		},
		"fieldScanType": func(f Field) string {
			if f.Nullable {
				return fmt.Sprintf("?%s", f.ZigType)
			}
			return f.ZigType
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
					if strings.HasPrefix(field.ZigType, enumsTypePrefix) {
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
						if strings.HasPrefix(field.ZigType, enumsTypePrefix) && field.Array {
							return true
						}
					}
				} else {
					if strings.HasPrefix(arg.Field.ZigType, enumsTypePrefix) && arg.Field.Array {
						return true
					}
				}
			}
			return false
		},
		"isEnum": func(field Field) bool {
			return strings.HasPrefix(field.ZigType, enumsTypePrefix)
		},
		"isNonScalar": func(field Field) bool {
			return isNonScalarBaseType(field.ZigType)
		},
		"allocType": func(field Field) string {
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
	}
}
