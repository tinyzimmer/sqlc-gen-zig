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

func hasNonScalarFields(s Struct) bool {
	for _, f := range s.Fields {
		if f.Array {
			return true
		}
		if isNonScalarBaseType(f) {
			return true
		}
	}
	return false
}

func isNonScalarBaseType(f Field) bool {
	if f.Enum {
		return false
	}
	switch f.ZigType {
	case "bool", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "f32", "f64", "char", "void":
		return false
	default:
		return true
	}
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
