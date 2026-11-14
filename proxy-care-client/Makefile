# Developer commands for the Proxy Care client. Run from this directory.
#
#   make get                      Resolve dependencies
#   make gen                      Run code generation (build_runner)
#   make format                   Format Dart sources
#   make format-check             Fail if any Dart source is not formatted
#   make analyze                  Static analysis (strict)
#   make test                     Run all tests
#   make check-env [ENV=...]      Validate config/$(ENV).json
#   make build-web [ENV=...]      Validate config, then release web build
#
# ENV defaults to development. Other environments read config/<ENV>.json,
# e.g. `make build-web ENV=production` uses config/production.json.

FLUTTER ?= flutter
DART ?= dart
ENV ?= development
DEFINES_FILE ?= config/$(ENV).json
DART_SOURCES := lib test tool

.PHONY: get gen format format-check analyze test check-env build-web

get:
	$(FLUTTER) pub get

gen:
	$(DART) run build_runner build

format:
	$(DART) format $(DART_SOURCES)

format-check:
	$(DART) format --output=none --set-exit-if-changed $(DART_SOURCES)

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

check-env:
	$(DART) run tool/check_env.dart $(DEFINES_FILE)

build-web: check-env
	$(FLUTTER) build web --release --dart-define-from-file=$(DEFINES_FILE)
