package zig

import (
	"fmt"
	"sort"

	"github.com/sqlc-dev/plugin-sdk-go/plugin"
)

type Enum struct {
	Name    string
	ZigName string
	Comment string
	Values  []string
}

func buildEnums(req *plugin.GenerateRequest) []Enum {
	var enums []Enum
	for _, schema := range req.GetCatalog().GetSchemas() {
		for _, enum := range schema.GetEnums() {
			var enumName string
			if schema.GetName() == req.GetCatalog().GetDefaultSchema() {
				enumName = enum.GetName()
			} else {
				enumName = fmt.Sprintf("%s_%s", schema.GetName(), enum.GetName())
			}
			enums = append(enums, Enum{
				Name:    enum.GetName(),
				ZigName: modelName(enumName),
				Comment: enum.GetComment(),
				Values:  enum.GetVals(),
			})
		}
	}
	sort.Slice(enums, func(i, j int) bool { return enums[i].ZigName < enums[j].ZigName })
	return enums
}

func enumType(catalog *plugin.Catalog, dbType string) string {
	for _, schema := range catalog.GetSchemas() {
		if isInternalSchema(schema.GetName()) {
			continue
		}
		for _, enum := range schema.GetEnums() {
			var enumDataType string
			if schema.GetName() == catalog.GetDefaultSchema() {
				enumDataType = enum.GetName()
			} else {
				enumDataType = fmt.Sprintf("%s.%s", schema.GetName(), enum.GetName())
			}
			if enumDataType == dbType {
				mname := func() string {
					if schema.GetName() == catalog.GetDefaultSchema() {
						return modelName(enumDataType)
					}
					return modelName(fmt.Sprintf("%s_%s", schema.GetName(), enum.GetName()))
				}()
				return mname
			}
		}
	}
	return ""
}
