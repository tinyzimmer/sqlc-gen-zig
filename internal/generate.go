package zig

import (
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"text/template"

	"github.com/sqlc-dev/plugin-sdk-go/plugin"
)

//go:embed templates/*.gotmpl
var templates embed.FS

func Generate(_ context.Context, req *plugin.GenerateRequest) (*plugin.GenerateResponse, error) {
	if err := validateRequest(req); err != nil {
		return nil, err
	}

	var conf Config
	conf.Default()
	if len(req.GetPluginOptions()) > 0 {
		if err := json.Unmarshal(req.GetPluginOptions(), &conf); err != nil {
			return nil, err
		}
	}
	if err := conf.Validate(); err != nil {
		return nil, err
	}

	models := buildModels(conf, req)
	enums := buildEnums(req)
	queries, err := buildQueries(conf, req, models)
	if err != nil {
		return nil, err
	}

	files, err := renderSourceFiles(conf, req, models, enums, queries)
	if err != nil {
		return nil, err
	}

	return &plugin.GenerateResponse{
		Files: files,
	}, nil
}

func validateRequest(req *plugin.GenerateRequest) error {
	switch req.GetSettings().GetEngine() {
	case "postgresql":
	default:
		return fmt.Errorf("unsupported engine: %s", req.GetSettings().GetEngine())
	}
	return nil
}

const (
	modelsFilename = "models.zig"
	enumsFilename  = "enums.zig"
)

func renderSourceFiles(conf Config, req *plugin.GenerateRequest, models []Struct, enums []Enum, queries []Query) ([]*plugin.File, error) {
	modelsFile, err := renderModels(conf, req, models)
	if err != nil {
		return nil, err
	}
	enumsFile, err := renderEnums(conf, req, enums)
	if err != nil {
		return nil, err
	}
	queryFiles, err := renderQueries(conf, req, queries, models)
	if err != nil {
		return nil, err
	}
	return append([]*plugin.File{modelsFile, enumsFile}, queryFiles...), nil
}

func renderModels(conf Config, req *plugin.GenerateRequest, models []Struct) (*plugin.File, error) {
	t := template.New("models.zig.gotmpl")
	t, err := t.Funcs(templateFuncs(t)).
		ParseFS(templates, "templates/helpers.gotmpl", "templates/models.zig.gotmpl")
	if err != nil {
		return nil, err
	}
	var modelsFile bytes.Buffer
	if err = t.Execute(&modelsFile, map[string]any{
		"Config":       conf,
		"SQLCVersion":  req.GetSqlcVersion(),
		"PGImportName": conf.Backend.ImportName(),
		"Models":       models,
		"EnumsFile":    enumsFilename,
	}); err != nil {
		return nil, err
	}
	return &plugin.File{
		Name:     modelsFilename,
		Contents: modelsFile.Bytes(),
	}, nil
}

func renderEnums(conf Config, req *plugin.GenerateRequest, enums []Enum) (*plugin.File, error) {
	t := template.New("enums.zig.gotmpl")
	t, err := t.Funcs(templateFuncs(t)).
		ParseFS(templates, "templates/helpers.gotmpl", "templates/enums.zig.gotmpl")
	if err != nil {
		return nil, err
	}
	var enumsFile bytes.Buffer
	if err = t.Execute(&enumsFile, map[string]any{
		"Config":      conf,
		"SQLCVersion": req.GetSqlcVersion(),
		"Enums":       enums,
	}); err != nil {
		return nil, err
	}
	return &plugin.File{
		Name:     enumsFilename,
		Contents: enumsFile.Bytes(),
	}, err
}

func renderQueries(conf Config, req *plugin.GenerateRequest, queries []Query, models []Struct) ([]*plugin.File, error) {
	t := template.New("queries.zig.gotmpl")
	t, err := t.Funcs(templateFuncs(t)).
		ParseFS(templates, "templates/helpers.gotmpl", "templates/queries.zig.gotmpl")
	if err != nil {
		return nil, err
	}
	// Group queries by their source name
	sourceQueries := make(map[string][]Query)
	for _, query := range queries {
		sourceQueries[query.SourceName] = append(sourceQueries[query.SourceName], query)
	}
	var files []*plugin.File
	for sourceName, queries := range sourceQueries {
		var queriesFile bytes.Buffer
		if err = t.Execute(&queriesFile, map[string]any{
			"Config":       conf,
			"SQLCVersion":  req.GetSqlcVersion(),
			"PGImportName": conf.Backend.ImportName(),
			"Queries":      queries,
			"Models":       models,
			"ModelsFile":   modelsFilename,
			"EnumsFile":    enumsFilename,
		}); err != nil {
			return nil, err
		}
		files = append(files, &plugin.File{
			Name:     fmt.Sprintf("%s.zig", sourceName),
			Contents: queriesFile.Bytes(),
		})
	}
	return files, nil
}

func getConfig(req *plugin.GenerateRequest) (conf Config, err error) {
	conf.Default()
	if len(req.PluginOptions) > 0 {
		if err := json.Unmarshal(req.PluginOptions, &conf); err != nil {
			return conf, err
		}
	}
	return conf, nil
}
