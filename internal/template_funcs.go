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
			return pad + strings.Replace(s, "\n", "\n"+pad, -1)
		},
		"hasNonScalarFields": func(s Struct) bool {
			for _, f := range s.Fields {
				if f.Array {
					return true
				}
				if strings.HasPrefix(f.ZigType, "enums.") {
					return false
				}
				switch f.ZigType {
				case "bool", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "f32", "f64", "char", "void":
					continue
				default:
					return true
				}
			}
			return false
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
				return fmt.Sprintf("models.%s", q.Ret.Struct.StructName)
			}
			return fmt.Sprintf("%s", q.Ret.ZigType)
		},
		"queryFuncArgs": func(q Query) string {
			var out strings.Builder
			out.WriteString("self: Self")
			for _, arg := range q.Args {
				out.WriteString(", ")
				if arg.Struct != nil {
					out.WriteString(fmt.Sprintf("%s: %s", arg.Name, arg.Struct.StructName))
				} else {
					out.WriteString(fmt.Sprintf("%s: %s", arg.Name, arg.ZigType))
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
			for i, arg := range q.Args {
				if i != 0 {
					out.WriteString(strings.Repeat(" ", indent))
				}
				if arg.Struct != nil {
					for i, field := range arg.Struct.Fields {
						if i != 0 {
							out.WriteString(fmt.Sprintf(",\n%s", strings.Repeat(" ", indent)))
						}
						if strings.HasPrefix(field.ZigType, "enums.") {
							out.WriteString(fmt.Sprintf("@tagName(%s.%s)", arg.Name, field.Name))
						} else {
							out.WriteString(fmt.Sprintf("%s.%s", arg.Name, field.Name))
						}
					}
				} else {
					out.WriteString(arg.Name)
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
			typ := f.ZigType
			if strings.HasPrefix(typ, "enums.") {
				return "[]const u8"
			}
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
					if strings.HasPrefix(field.ZigType, "enums.") {
						return true
					}
				}
			}
			return false
		},
		"isEnum": func(field Field) bool {
			return strings.HasPrefix(field.ZigType, "enums.")
		},
		"isNonScalar": func(field Field) bool {
			if field.Array {
				return true
			}
			if strings.HasPrefix(field.ZigType, "enums.") {
				return false
			}
			switch field.ZigType {
			case "bool", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "f32", "f64", "char", "void":
				return false
			default:
				return true
			}
		},
		"allocType": func(field Field) string {
			if field.Array {
				panic("unimplemented")
			}
			baseType := strings.TrimPrefix(field.ZigType, "[]")
			baseType = strings.TrimPrefix(baseType, "const ")
			return baseType
		},
		"snakeCase": func(s string) string {
			return snakeCase(s)
		},
	}
}
