# Proxy Care client

Flutter Web client for **Proxy Care**, an app where families book a vetted
caretaker to accompany a family member to hospital visits (OPD, diagnostics,
day-care procedures, admission and discharge), and caretakers run the visit.

This package is built in milestones. **Milestone 1** sets up the project: Flutter
Web, dependencies, strict static analysis, compile-time environment
configuration, developer commands and CI. There are no screens yet; the app
starts, validates its configuration and renders nothing.

## Toolchain

| Tool | Version |
| --- | --- |
| Flutter | 3.50.x, stable channel (CI uses the newest 3.50 patch) |
| Dart | 3.14 (bundled with Flutter 3.50) |
| Platform | Web only |

`pubspec.yaml` requires Dart `^3.14.0` and Flutter `>=3.50.0`.

## Dependencies

| Package | Constraint | Purpose |
| --- | --- | --- |
| `go_router` | ^18.1.1 | Declarative routing |
| `flutter_riverpod` | ^3.5.0 | State management and dependency injection |
| `dio` | ^5.11.1 | HTTP client |
| `flutter_secure_storage` | ^11.2.0 | Secure storage for tokens and secrets |
| `freezed_annotation` | ^3.1.0 | Annotations for immutable models (Freezed) |
| `json_annotation` | ^4.12.0 | Annotations for JSON serialization |
| `logger` | ^2.8.0 | Logging |
| `intl` | ^0.20.3 | Dates, numbers and currency formatting |
| `material_ui` | ^1.11.0 | Material widgets; Flutter 3.50 deprecates `package:flutter/material.dart` in favour of this package |

Development:

| Package | Constraint | Purpose |
| --- | --- | --- |
| `build_runner` | ^2.17.1 | Runs code generators |
| `freezed` | ^4.0.3 | Generates immutable models |
| `json_serializable` | ^6.15.2 | Generates JSON (de)serializers |
| `mocktail` | ^1.0.5 | Mocks for tests |
| `flutter_lints` | ^6.0.0 | Base lint rules |

Riverpod code generation (`riverpod_annotation` / `riverpod_generator`) is not
used; providers are written by hand.

Most packages are not used yet; they are in place for the following milestones.

## Local setup

```sh
cd proxy-care-client
make get        # flutter pub get
make gen        # build_runner (no generated files yet)
make analyze
make test
```

Web support is enabled by default in current Flutter. If `flutter devices` does
not list Chrome, run `flutter config --enable-web`.

Run locally with the development configuration:

```sh
flutter run -d chrome --dart-define-from-file=config/development.json
```

## Environment configuration

Configuration is passed at build time with `--dart-define-from-file` (or
individual `--dart-define` flags) and read in `lib/core/config/env.dart` using
`String.fromEnvironment`. `Env.fromEnvironment()` validates everything at
start-up and throws an `EnvConfigException` listing every problem.

| Define | Values | Default |
| --- | --- | --- |
| `APP_ENV` | `development`, `staging`, `production` | `development` |
| `API_BASE_URL` | Absolute `http`/`https` URL, no query or fragment | `http://localhost:8080`, **development only** |
| `APP_NAME` | Any text | `Proxy Care` |
| `ENABLE_LOGGING` | `true` or `false` | `false` in production, otherwise `true` |
| `FEATURE_FLAGS` | Comma-separated snake_case names, e.g. `new_checkout,beta_maps` | none |

Rules for staging and production:

- `API_BASE_URL` is **required**; there is no fallback to the development URL.
- It must use `https`.
- In production it must not point to `localhost`, `127.0.0.1`, `0.0.0.0`,
  `::1` or `10.0.2.2`.

Config files live in `config/`:

| File | Committed | Notes |
| --- | --- | --- |
| `config/development.json` | Yes | Local backend at `http://localhost:8080`; change the port to match your backend. |
| `config/staging.example.json` | Yes | Copy to `config/staging.json` and set `API_BASE_URL`. |
| `config/production.example.json` | Yes | Copy to `config/production.json` and set `API_BASE_URL`. |
| `config/staging.json`, `config/production.json` | No (git-ignored) | Real values. |

Check a file without building:

```sh
make check-env ENV=production   # validates config/production.json
```

## Build

```sh
make build-web                  # development config
make build-web ENV=staging      # needs config/staging.json
make build-web ENV=production   # needs config/production.json
```

`build-web` first validates the config file, then runs
`flutter build web --release --dart-define-from-file=config/<ENV>.json`.
Output goes to `build/web/`.

## Make commands

| Command | What it does |
| --- | --- |
| `make get` | `flutter pub get` |
| `make gen` | `dart run build_runner build` |
| `make format` | `dart format lib test tool` |
| `make format-check` | Fails if any file is not formatted |
| `make analyze` | `flutter analyze` with the strict settings in `analysis_options.yaml` |
| `make test` | `flutter test` |
| `make check-env [ENV=...]` | Validates `config/<ENV>.json` |
| `make build-web [ENV=...]` | Validates the config, then builds a release web bundle |

## Static analysis

`analysis_options.yaml` includes `flutter_lints` and turns on:

- `strict-casts`, `strict-inference`, `strict-raw-types`
- `prefer_const_constructors`, `prefer_const_declarations`,
  `prefer_const_literals_to_create_immutables`, `prefer_final_locals`,
  `prefer_single_quotes`
- `require_trailing_commas`, with the formatter set to
  `trailing_commas: preserve`: any argument or parameter list that is split
  across lines ends with a trailing comma.

Generated `*.g.dart` and `*.freezed.dart` files are excluded from analysis.

## Continuous integration

`.github/workflows/ci.yml` (at the repository root) runs on every push to
`main` and on pull requests that touch `proxy-care-client/`:

1. Install Flutter 3.50.x (stable).
2. `make get`.
3. Check formatting.
4. `make gen`.
5. `make analyze`.
6. `make test`.
7. Confirm a production config without `API_BASE_URL` is rejected.
8. `make build-web` (release, development config).

The resolved `pubspec.lock` is uploaded as a build artifact.

## Project structure

```text
proxy-care-client/
├── config/                 Compile-time defines per environment
├── lib/
│   ├── app.dart            Root widget (no screens yet)
│   ├── main.dart           Entry point: validates Env, starts the app
│   └── core/config/        Env, AppEnvironment, EnvConfigException
├── test/                   Unit and widget tests
├── tool/check_env.dart     Validates a config file from the command line
├── web/                    Web entry files and icons
├── analysis_options.yaml
├── Makefile
└── pubspec.yaml
```

## Design system

Visual design follows the Proxy Care Design System
(`claude/proxycare-design-system.md` in the Proxy Care project). It is not
implemented yet; the web manifest only uses its background (`#F4FBF8`) and
primary (`#006A60`) colors. The web icons are plain placeholders until brand
artwork exists.
