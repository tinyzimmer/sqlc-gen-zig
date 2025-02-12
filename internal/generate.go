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

//go:embed templates/**/*.gotmpl
var templates embed.FS

func Generate(_ context.Context, req *plugin.GenerateRequest) (*plugin.GenerateResponse, error) {
	if err := validateRequest(req); err != nil {
		return nil, err
	}

	conf, err := getConfig(req)
	if err != nil {
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
	case enginePostgres, engineSqlite:
	default:
		return fmt.Errorf("unsupported engine: %s", req.GetSettings().GetEngine())
	}
	return nil
}

func renderSourceFiles(conf Config, req *plugin.GenerateRequest, models []Struct, enums []Enum, queries []Query) ([]*plugin.File, error) {
	modelsFile, err := renderModels(conf, req, models, enums)
	if err != nil {
		return nil, err
	}
	queryFiles, err := renderQueries(conf, req, queries, models, enums)
	if err != nil {
		return nil, err
	}
	return append(queryFiles, modelsFile), nil
}

const modelsFilename = "models.zig"

func renderModels(conf Config, req *plugin.GenerateRequest, models []Struct, enums []Enum) (*plugin.File, error) {
	t := template.New("models.zig.gotmpl")
	t, err := t.Funcs(templateFuncs(t)).
		ParseFS(templates, templatePaths(req, modelsTemplate)...)
	if err != nil {
		return nil, err
	}
	var modelsFile bytes.Buffer
	if err = t.Execute(&modelsFile, map[string]any{
		"Config":       conf,
		"SQLCVersion":  req.GetSqlcVersion(),
		"DBImportName": conf.Backend.ImportName(),
		"Models":       models,
		"Enums":        enums,
	}); err != nil {
		return nil, err
	}
	return &plugin.File{
		Name:     modelsFilename,
		Contents: modelsFile.Bytes(),
	}, nil
}

func renderQueries(conf Config, req *plugin.GenerateRequest, queries []Query, models []Struct, enums []Enum) ([]*plugin.File, error) {
	t := template.New("queries.zig.gotmpl")
	t, err := t.Funcs(templateFuncs(t)).
		ParseFS(templates, templatePaths(req, queriesTemplate)...)
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
			"DBImportName": conf.Backend.ImportName(),
			"Queries":      queries,
			"Models":       models,
			"Enums":        enums,
			"ModelsFile":   modelsFilename,
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
	conf.Default(req)
	if len(req.PluginOptions) > 0 {
		if err := json.Unmarshal(req.PluginOptions, &conf); err != nil {
			return conf, err
		}
	}
	return conf, conf.Validate(req)
}

type zigTemplate string

const (
	modelsTemplate  zigTemplate = "models"
	queriesTemplate zigTemplate = "queries"
)

func templatePaths(req *plugin.GenerateRequest, tmpl zigTemplate) []string {
	engine := req.GetSettings().GetEngine()
	switch tmpl {
	case modelsTemplate:
		return []string{
			fmt.Sprintf("templates/%s/helpers.gotmpl", engine),
			fmt.Sprintf("templates/%s/models.zig.gotmpl", engine),
		}
	case queriesTemplate:
		return []string{
			fmt.Sprintf("templates/%s/helpers.gotmpl", engine),
			fmt.Sprintf("templates/%s/queries.zig.gotmpl", engine),
		}
	default:
		panic("Unknown template")
	}
}
