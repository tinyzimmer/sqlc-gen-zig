package zig

import (
	"fmt"
	"sort"

	"github.com/sqlc-dev/plugin-sdk-go/plugin"

	"github.com/tinyzimmer/sqlc-gen-zig/internal/inflection"
)

type Struct struct {
	ID         Identifier
	TableName  string
	StructName string
	Comment    string
	Fields     []Field
}

type Identifier struct {
	Schema string
	Name   string
}

func buildModels(conf Config, req *plugin.GenerateRequest) []Struct {
	var structs []Struct
	for _, schema := range req.GetCatalog().GetSchemas() {
		if isInternalSchema(schema.GetName()) {
			continue
		}
		for _, table := range schema.GetTables() {
			var tableName string
			if schema.GetName() == req.GetCatalog().GetDefaultSchema() {
				tableName = table.GetRel().GetName()
			} else {
				tableName = fmt.Sprintf("%s_%s", schema.GetName(), table.GetRel().GetName())
			}
			structName := tableName
			if conf.EmitExactTableNames {
				structName = inflection.Singular(inflection.SingularParams{
					Name:       structName,
					Exclusions: conf.InflectionExcludeTableNames,
				})
			}
			structs = append(structs, Struct{
				ID:         Identifier{Schema: schema.GetName(), Name: table.GetRel().GetName()},
				TableName:  tableName,
				StructName: modelName(structName),
				Comment:    table.Comment,
				Fields:     buildFields(conf, req, table.GetColumns()),
			})
		}
	}
	sort.Slice(structs, func(i, j int) bool { return structs[i].StructName < structs[j].StructName })
	return structs
}
