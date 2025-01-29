package zig

import (
	"regexp"
	"strings"

	"golang.org/x/text/cases"
	"golang.org/x/text/language"
)

func isInternalSchema(schema string) bool {
	return schema == "pg_catalog" || schema == "information_schema"
}

func modelName(name string) string {
	caser := cases.Title(language.English)
	var out string
	for _, part := range strings.Split(name, "_") {
		out += caser.String(part)
	}
	return out
}

func camelCase(s string) string {
	s = regexp.MustCompile("[^a-zA-Z0-9_ ]+").ReplaceAllString(s, "")

	s = strings.ReplaceAll(s, "_", " ")
	s = cases.Title(language.AmericanEnglish, cases.NoLower).String(s)
	s = strings.ReplaceAll(s, " ", "")

	if len(s) > 0 {
		s = strings.ToLower(s[:1]) + s[1:]
	}

	return s
}

func pascalCase(s string) string {
	s = regexp.MustCompile("[^a-zA-Z0-9_ ]+").ReplaceAllString(s, "")

	s = strings.ReplaceAll(s, "_", " ")
	s = cases.Title(language.AmericanEnglish, cases.NoLower).String(s)
	s = strings.ReplaceAll(s, " ", "")

	return s
}

var matchFirstCap = regexp.MustCompile("(.)([A-Z][a-z]+)")
var matchAllCap = regexp.MustCompile("([a-z0-9])([A-Z])")

func snakeCase(name string) string {
	snake := matchFirstCap.ReplaceAllString(name, "${1}_${2}")
	snake = matchAllCap.ReplaceAllString(snake, "${1}_${2}")
	return strings.ToLower(snake)
}
