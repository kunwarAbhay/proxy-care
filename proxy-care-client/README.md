# Proxy Care client

Flutter Web client for **Proxy Care**, an app where families book a vetted
caretaker to accompany a family member to hospital visits (OPD, diagnostics,
day-care procedures, admission and discharge), and caretakers run the visit.

This package is built in milestones (project set-up, architecture and
dependency injection, design system, error handling so far). There are no
screens yet; the app starts, validates its configuration and renders nothing.

See [MVP decisions](#mvp-decisions) for the decisions that shape the
project.

## Toolchain

| Tool | Version |
| --- | --- |
| Flutter | 3.50.x, stable channel (CI uses the newest 3.50 patch) |
| Dart | 3.14 (bundled with Flutter 3.50) |
| Platform | Web only for now (the move to Android and iOS is deferred) |

`pubspec.yaml` requires Dart `^3.14.0` and Flutter `>=3.50.0`.

## Dependencies

| Package | Constraint | Purpose |
| --- | --- | --- |
| `go_router` | ^18.1.1 | Declarative routing |
| `flutter_riverpod` | ^3.5.0 | State management and dependency injection |
| `connectivity_plus` | ^7.3.2 | Network connection status (not reachability) |
| `dio` | ^5.11.1 | HTTP client |
| `flutter_secure_storage` | ^11.2.0 | Secure storage for the Supabase session (Keystore / Keychain / WebCrypto) |
| `supabase_flutter` | ^2.18.3 | Supabase Auth (identity provider); sessions persisted through secure storage |
| `freezed_annotation` | ^3.1.0 | Annotations for immutable models (Freezed) |
| `json_annotation` | ^4.12.0 | Annotations for JSON serialization |
| `logger` | ^2.8.0 | Logging |
| `intl` | ^0.20.3 | Dates, numbers and currency formatting; used by the generated localizations |
| `flutter_localizations` | SDK | Localization delegates for ARB-based strings |
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

Some packages are not used yet; they are in place for the following
milestones.

### Lockfile

`pubspec.lock` is committed (this is an application, not a reusable
package). `make get` (`flutter pub get`) updates it; commit the change with
the `pubspec.yaml` change that caused it. CI fails if resolving the
dependencies would change the committed lockfile. Use `make get-locked`
(`flutter pub get --enforce-lockfile`) to install exactly what it pins.

## Local setup

```sh
cd proxy-care-client
make get        # flutter pub get
make gen        # build_runner + flutter gen-l10n
make analyze
make test
```

Web support is enabled by default in current Flutter. If `flutter devices` does
not list Chrome, run `flutter config --enable-web`.

Run locally with the development configuration:

```sh
flutter run -d chrome --dart-define-from-file=config/env/development.json
```

### Generated files

Generated Dart files are committed: `*.g.dart`, `*.freezed.dart` and the
localizations in `lib/core/l10n/generated/`. After changing an annotated
model or an ARB file, run `make gen` and `make format` and commit the result.
Never edit generated files by hand. CI regenerates everything and fails if
the committed files differ.

## Environment configuration

Configuration is passed at build time with `--dart-define-from-file` (or
individual `--dart-define` flags) and read in `lib/core/config/env.dart` using
`String.fromEnvironment`. `Env.fromEnvironment()` validates everything at
start-up and throws an `EnvConfigException` listing every problem.

| Define | Values | Default |
| --- | --- | --- |
| `APP_ENV` | `development`, `staging`, `production` | `development` in debug builds and tests only; **required** in release builds and config files |
| `API_BASE_URL` | Absolute `http`/`https` URL, no query or fragment | `http://localhost:8080`, **development only** |
| `APP_NAME` | Any text | `Proxy Care` |
| `ENABLE_LOGGING` | `true` or `false` | `false` in production, otherwise `true` |
| `FEATURE_FLAGS` | Comma-separated snake_case names, e.g. `new_checkout,beta_maps` | none |
| `SUPABASE_URL` | Supabase project URL (`https://<ref>.supabase.co`); http allowed in development for a local stack | none: required in staging and production, optional in development (the app then runs signed out) |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase **publishable** key (`sb_publishable_…`, or a legacy anon key). Secret and service-role keys are rejected. | as above; set together with `SUPABASE_URL` |

Production configuration never silently falls back to development: a
release build without `APP_ENV` fails at start-up, and `make check-env`
rejects a file without it.

Rules for staging and production:

- `API_BASE_URL` is **required**; there is no fallback to the development URL.
- It must use `https`.
- In production it must not point to `localhost`, `127.0.0.1`, `0.0.0.0`,
  `::1` or `10.0.2.2`.

Config files live in `config/env/` and are committed. They hold
**non-sensitive** values only:

| File | Notes |
| --- | --- |
| `config/env/development.json` | Local backend at `http://localhost:8080`; change the port to match your backend. |
| `config/env/staging.json` | `API_BASE_URL` is empty until the staging URL is known, so a staging build fails validation instead of using another URL. |
| `config/env/production.json` | Same for production. |

Never commit API secrets, private keys, database credentials, payment
provider secrets, signing credentials or authentication secrets. Values
passed with `--dart-define` end up in the app binary and are readable by
anyone who has it, so they are not secure storage; sensitive credentials
stay in backend infrastructure or CI secret management.

Check a file without building:

```sh
make check-env ENV=production   # validates config/env/production.json
```

## Build

```sh
make build-web                  # development config
make build-web ENV=staging      # needs API_BASE_URL in config/env/staging.json
make build-web ENV=production   # needs API_BASE_URL in config/env/production.json
```

`build-web` first validates the config file, then runs
`flutter build web --release --dart-define-from-file=config/env/<ENV>.json`.
Output goes to `build/web/`.

## Make commands

| Command | What it does |
| --- | --- |
| `make get` | `flutter pub get` (updates `pubspec.lock`) |
| `make get-locked` | `flutter pub get --enforce-lockfile` |
| `make gen` | `dart run build_runner build --delete-conflicting-outputs`, then `flutter gen-l10n` |
| `make format` | `dart format .` |
| `make format-check` | Fails if any file is not formatted |
| `make analyze` | `flutter analyze` with the strict settings in `analysis_options.yaml` |
| `make test` | `flutter test` |
| `make check-env [ENV=...]` | Validates `config/env/<ENV>.json` |
| `make build-web [ENV=...]` | Validates the config, then builds a release web bundle |
| `make build-showcase [BASE_HREF=/repo/]` | Release web build of the widget showcase (`config/env/showcase.json`) |

## Static analysis

`analysis_options.yaml` includes `flutter_lints` and turns on:

- `strict-casts`, `strict-inference`, `strict-raw-types`
- `prefer_const_constructors`, `prefer_const_declarations`,
  `prefer_const_literals_to_create_immutables`, `prefer_final_locals`,
  `prefer_single_quotes`
- `require_trailing_commas`, with the formatter set to
  `trailing_commas: preserve`: any argument or parameter list that is split
  across lines ends with a trailing comma.

Generated `*.g.dart`, `*.freezed.dart` and `lib/core/l10n/generated/` files
are excluded from analysis.

## Continuous integration

`.github/workflows/ci.yml` (at the repository root) runs on every push to
`main` and on pull requests that touch `proxy-care-client/`:

1. Install Flutter 3.50.x (stable).
2. `make get`, `make gen` (build_runner and gen-l10n), `make format`.
3. Fail if that changed anything tracked or added anything new: the
   committed `pubspec.lock`, generated files and formatting must be current.
4. `make analyze`.
5. `make test`.
6. Validate the development config, and confirm a production config without
   `API_BASE_URL`, or any config without `APP_ENV`, is rejected.
7. `make build-web` (release, development config).

CI does not depend on downloaded artifacts: everything it needs is in the
repository.

`.github/workflows/pages.yml` publishes the widget showcase (below) to
GitHub Pages on every push to `main` that touches `proxy-care-client/`, and
on demand: it repeats the checks above (`make get-locked`, `make gen`,
`make format-check`, `make analyze`, `make test`), runs
`make build-showcase BASE_HREF=/<repository>/`, adds a `404.html` that
forwards path links to the app's hash URLs, and deploys with
`actions/deploy-pages`. It needs Pages enabled with **Source: GitHub
Actions** in the repository settings.

## Project structure

```text
proxy-care-client/
├── ARCHITECTURE.md         Layers, dependency rules, DI and feature conventions
├── AUTHENTICATION.md       Supabase Auth, session storage, Dio integration
├── SECURITY.md             Token storage, logging, backend JWT validation
├── TESTING.md              Test layout, helpers, rules, integration and goldens
├── assets/fonts/          Bundled Noto Sans Devanagari (OFL)
├── config/env/             Compile-time defines per environment
├── docs/                   Design system, navigation, deep linking, observability
├── lib/
│   ├── main.dart           Entry point: bootstrap, then runApp
│   ├── app.dart            Root widget: theme, localization, router
│   ├── app_routes.dart     Feature route modules (none yet) and the
│   │                       dev-only widget showcase switch
│   ├── core/               Infrastructure: config, di, error, l10n, network,
│   │                       router, security, theme, utils, widgets, services,
│   │                       constants
│   ├── features/auth/      Empty data / domain / presentation layer folders
│   ├── features/widget_showcase/
│   │                       Dev-only /widget-showcase component preview
│   └── shared/             Cross-feature models, widgets, extensions
├── test/                   Mirrors lib/, plus architecture, fixtures, helpers,
│                           mocks
├── tool/check_env.dart     Validates a config file from the command line
├── tool/github_pages/      404.html redirect for the GitHub Pages showcase
├── web/                    Web entry files and icons
├── analysis_options.yaml
├── l10n.yaml               flutter gen-l10n configuration
├── Makefile
└── pubspec.yaml
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the layer rules (checked by
`test/architecture/dependency_rules_test.dart`), Riverpod dependency-injection
conventions and how a feature module is built.

## Design system

The UI follows the Proxy Care Design System (`claude/proxycare-design-system.md`
in the Proxy Care project), the single source of truth. It is implemented
as:

- tokens and theme in `lib/core/theme/` (`buildProxyCareTheme`, the
  `PcTheme` extension, the density providers);
- components in `lib/shared/widgets/` (`PcButton`, `PcTextField`, `PcCard`,
  …).

[docs/design-system-mapping.md](docs/design-system-mapping.md) maps every
token and component to code and records how each ambiguity in the spec was
handled. The design system defines a light theme only, in two densities:
standard (family app) and comfortable (caretaker app). The web icons are
plain placeholders until brand artwork exists.

### Widget showcase

`/widget-showcase` (`lib/features/widget_showcase/`) shows every component in
`lib/shared/widgets/` with its variants, sizes and states, grouped by
category, with a switch to preview either density. It is a development
preview only: interactions use in-memory state and call no API.

- It is registered only when `FEATURE_FLAGS` contains `widget_showcase` and
  `APP_ENV` is not `production` (`WidgetShowcaseRoutes.isEnabled`). The
  development, staging and production configs leave it off.
- `config/env/showcase.json` is the development config with the flag on:
  `flutter run -d chrome --dart-define-from-file=config/env/showcase.json`,
  then open `/#/widget-showcase`.
- Published by `pages.yml` at
  `https://<owner>.github.io/<repository>/#/widget-showcase`.

## MVP decisions

| Decision | Status |
| --- | --- |
| Commit `pubspec.lock` | Implemented; CI checks it |
| Commit generated files; CI fails if regeneration changes them | Implemented |
| Non-sensitive config in `config/env/*.json`; no secrets; production never falls back to development | Implemented |
| Android and iOS only | **Deferred**: the app stays web-only until the platform move is scheduled |
| Native platform typography; bundle Noto Sans Devanagari only | Implemented (400, 500, 700; SIL OFL 1.1, licence registered at start-up) |
| Flutter's built-in Material icons | Implemented |
| Provisional breakpoints: compact < 600dp, tablet ≥ 600dp, 720dp max content width | Implemented in `PcBreakpoints` (configurable) |
| Light theme only | Implemented |
| Standard backend error envelope and codes | Implemented in `ErrorMapper` |
| Vendor-independent crash reporter, no-op for the MVP (Crashlytics is LL-05) | Implemented |
| Localized user-facing error messages (ARB, English) | Implemented in `core/l10n` |

