SQLC_VERSION := v1.28.0
SQLC := go run github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)

PLUGIN_FILE := $(CURDIR)/bin/sqlc-gen-zig.wasm

build:
	GOOS=wasip1 GOARCH=wasm go build -o "$(PLUGIN_FILE)" .

e2e: build patch-sqlc-yaml
	cd tests/e2e && $(SQLC) generate

SQLC_TEMPLATE := $(CURDIR)/tests/e2e/sqlc.template.yaml
SQLC_OUTPUT := $(CURDIR)/tests/e2e/sqlc.yaml
patch-sqlc-yaml:
	cat "$(SQLC_TEMPLATE)" | \
		sed 's|{{PLUGIN_PATH}}|$(PLUGIN_FILE)|g' | \
		sed 's|{{PLUGIN_SHA256}}|$(shell sha256sum $(PLUGIN_FILE) | cut -d ' ' -f 1)|g' \
		> "$(SQLC_OUTPUT)"
