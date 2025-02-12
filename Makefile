GO  ?= $(shell go env GOROOT)/bin/go
ZIG ?= $(shell zig env | jq -r .zig_exe)

SQLC_VERSION := v1.28.0
SQLC := $(GO) run github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)

PLUGIN_FILE := $(CURDIR)/bin/sqlc-gen-zig.wasm

build:
	GOOS=wasip1 GOARCH=wasm $(GO) build -o "$(PLUGIN_FILE)" .

e2e: build e2e-postgres e2e-sqlite

e2e-postgres: build patch-sqlc-yaml-postgres gen-e2e-postgres run-e2e-postgres

e2e-sqlite: build patch-sqlc-yaml-sqlite gen-e2e-sqlite run-e2e-sqlite

gen-e2e: build patch-sqlc-yaml-postgres patch-sqlc-yaml-sqlite gen-e2e-postgres gen-e2e-sqlite

gen-e2e-%:
	cd tests/e2e/$* && $(SQLC) generate

run-e2e: run-e2e-postgres run-e2e-sqlite

run-e2e-%:
	cd tests/e2e/$* && if [ -f "docker-compose.yaml" ]; then docker compose up -d && sleep 5 ; fi
	cd tests/e2e/$* && $(ZIG) build test
	cd tests/e2e/$* && if [ -f "docker-compose.yaml" ]; then docker compose down -v ; fi

patch-sqlc-yaml: patch-sqlc-yaml-postgres patch-sqlc-yaml-sqlite

patch-sqlc-yaml-%:
	cat "$(CURDIR)/tests/e2e/$*/sqlc.template.yaml" | \
		sed 's|{{PLUGIN_PATH}}|$(PLUGIN_FILE)|g' | \
		sed 's|{{PLUGIN_SHA256}}|$(shell sha256sum "$(PLUGIN_FILE)" | cut -d ' ' -f 1)|g' \
		> "$(CURDIR)/tests/e2e/$*/sqlc.yaml"

clean:
	rm -rf bin/ dist/
	rm -rf tests/e2e/sqlc.yaml tests/e2e/src/gen
