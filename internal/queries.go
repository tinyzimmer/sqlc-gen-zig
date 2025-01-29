package zig

import (
	"errors"
	"fmt"
	"sort"

	"github.com/sqlc-dev/plugin-sdk-go/metadata"
	"github.com/sqlc-dev/plugin-sdk-go/plugin"
	"github.com/sqlc-dev/plugin-sdk-go/sdk"
)

type Query struct {
	Cmd          string
	Comments     []string
	MethodName   string
	FieldName    string
	ConstantName string
	SQL          string
	SourceName   string
	Ret          *QueryValue
	Args         []QueryValue
}

type QueryValue struct {
	Emit    bool
	Name    string
	Struct  *Struct
	ZigType string
}

func buildQueries(conf Config, req *plugin.GenerateRequest, structs []Struct) ([]Query, error) {
	queries := make([]Query, 0, len(req.Queries))
	for _, query := range req.Queries {
		if query.GetName() == "" {
			continue
		}
		if query.GetCmd() == "" {
			continue
		}
		if query.GetCmd() == metadata.CmdCopyFrom {
			return nil, errors.New("Support for CopyFrom in Zig is not implemented")
		}

		gq := Query{
			Cmd:        query.GetCmd(),
			Comments:   query.GetComments(),
			MethodName: camelCase(query.GetName()),
			// FieldName:    sdk.LowerTitle(query.GetName()) + "Stmt",
			ConstantName: snakeCase(query.GetName() + "Sql"),
			SQL:          query.GetText(),
			SourceName:   query.GetFilename(),
		}

		// Parse query parameters
		if len(query.GetParams()) <= conf.QueryParameterLimit {
			// Inline the parameters
			for _, param := range query.GetParams() {
				gq.Args = append(gq.Args, QueryValue{
					Name:    paramName(param),
					ZigType: zigDataType(req, param.GetColumn()),
				})
			}
		} else {
			// Create a struct for the parameters
			st := paramsToStruct(conf, req, query, query.GetParams())
			gq.Args = []QueryValue{{
				Name:   snakeCase(st.StructName),
				Struct: st,
				Emit:   true,
			}}
		}

		// Parse query return values
		if len(query.GetColumns()) > 0 {
			if len(query.GetColumns()) == 1 {
				col := query.GetColumns()[0]
				gq.Ret = &QueryValue{
					Name:    columnName(col, 0),
					ZigType: zigDataType(req, query.GetColumns()[0]),
				}
			} else {
				var st *Struct
				var emit bool
				for _, s := range structs {
					if len(s.Fields) != len(query.Columns) {
						continue
					}
					same := true

					for i, f := range s.Fields {
						c := query.GetColumns()[i]
						sameName := f.Name == columnName(c, i)
						sameType := f.ZigType == zigDataType(req, c)
						sameTable := sdk.SameTableName(c.Table, &plugin.Identifier{Name: s.ID.Name, Schema: s.ID.Schema}, req.Catalog.DefaultSchema)
						if !sameName || !sameType || !sameTable {
							same = false
						}
					}
					if same {
						st = &s
						break
					}
				}
				if st == nil {
					st = columnsToStruct(conf, req, query, query.GetColumns())
					emit = true
				}
				gq.Ret = &QueryValue{
					Emit:   emit,
					Struct: st,
				}
			}
		}

		queries = append(queries, gq)
	}
	sort.Slice(queries, func(i, j int) bool { return queries[i].MethodName < queries[j].MethodName })
	return queries, nil
}

func paramsToStruct(conf Config, req *plugin.GenerateRequest, query *plugin.Query, params []*plugin.Parameter) *Struct {
	structName := fmt.Sprintf("%sParams", pascalCase(query.GetName()))
	gs := Struct{
		TableName:  structName,
		StructName: structName,
		Comment:    fmt.Sprintf("Parameters for %s", query.GetName()),
		Fields: buildFields(conf, req, func() []*plugin.Column {
			var columns []*plugin.Column
			for _, param := range params {
				columns = append(columns, param.GetColumn())
			}
			return columns
		}()),
	}
	// Force CIDR/INET fields and Numerics to native types
	for i, field := range gs.Fields {
		switch field.ZigType {
		case "pg.Cidr":
			gs.Fields[i].ZigType = "[]const u8"
		case "pg.Numeric":
			gs.Fields[i].ZigType = "f64"
		}
	}
	return &gs
}

func columnsToStruct(conf Config, req *plugin.GenerateRequest, query *plugin.Query, columns []*plugin.Column) *Struct {
	structName := fmt.Sprintf("%sRow", pascalCase(query.GetName()))
	gs := Struct{
		TableName:  structName,
		StructName: structName,
		Comment:    fmt.Sprintf("Result for %s", query.GetName()),
		Fields:     buildFields(conf, req, columns),
	}
	return &gs
}

func paramName(param *plugin.Parameter) string {
	if param.GetColumn().GetName() != "" {
		return snakeCase(param.GetColumn().GetName())
	}
	return fmt.Sprintf("param_%d", param.GetNumber())
}

func columnName(c *plugin.Column, pos int) string {
	if c.Name != "" {
		return c.Name
	}
	return fmt.Sprintf("column_%d", pos+1)
}
