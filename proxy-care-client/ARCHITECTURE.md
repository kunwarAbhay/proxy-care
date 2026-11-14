# Architecture

How the Proxy Care client is structured, and the rules every feature
follows. The rules marked **enforced** are checked by
`test/architecture/dependency_rules_test.dart`, so breaking one fails CI.

## Layers and dependency direction

```text
                 ┌────────────────────────────────────────┐
                 │ app.dart / main.dart / core/di          │  composition root
                 └───────────────┬────────────────────────┘
                                 │ wires
        ┌────────────────────────┼─────────────────────────┐
        ▼                        ▼                         ▼
  presentation  ───────────▶  domain  ◀───────────────  data
  (controllers,               (entities,                (DTOs, mappers,
   widgets)                    repository interfaces,    data sources,
                               use cases)                repository impls)
        │                        │                         │
        └──────────┬─────────────┴───────────┬─────────────┘
                   ▼                         ▼
                 shared                    core
       (models, widgets, extensions)  (config, di, error, network,
                                       router, security, theme, …)
```

Arrows point from the code that depends to the code it depends on.

- **Domain depends on nothing outside itself**, except the pure-Dart
  contracts `core/error/failure.dart`, `core/error/error_reporter.dart`,
  `core/config` and `shared/models`.
- **Data depends on domain.** It implements domain repository interfaces and
  uses core infrastructure (Dio, secure storage).
- **Presentation depends on domain.** It calls use cases and repository
  interfaces and never touches data-layer classes.
- **Core and shared depend on no feature.**
- **The composition root** (`main.dart`, `app.dart`, `core/di`, and each
  feature's `<feature>_providers.dart`) is the only code that knows both
  interfaces and implementations.

### Rules

| Rule | Enforced |
| --- | --- |
| Domain imports no Flutter (`package:flutter`, `material_ui`, `dart:ui`) | Yes |
| Domain imports no Dio, Riverpod, secure storage or `json_annotation` | Yes |
| Domain imports nothing from `data/` or `presentation/` | Yes |
| Types the domain uses (`shared/models`, `core/config`, `AppFailure`, `ErrorReporter`) are pure Dart | Yes |
| Infrastructure exceptions (`AppException`, `ErrorMapper`, `guardResult`, `decodeResponse`) are used only by core and data, never by domain, presentation or shared | Yes |
| Data imports nothing from `presentation/` | Yes |
| Presentation imports nothing from `data/` and no Dio | Yes |
| `core/` and `shared/` import no feature | Yes |
| DTOs never appear in domain signatures; mappers convert at the boundary | By review |
| Infrastructure is injected through providers, never constructed inside a class that uses it | By review |

## Layer responsibilities

| Layer | Contains | Must not |
| --- | --- | --- |
| **Domain** | Entities, repository interfaces, use cases. Business rules. | Know about HTTP, JSON, Flutter, Riverpod or storage. |
| **Data** | DTOs, mappers, remote and local data sources, repository implementations. | Leak DTOs or Dio types outside `data/`. Contain UI logic. |
| **Presentation** | Riverpod controllers (`Notifier`, `AsyncNotifier`) and widgets. | Call data sources or build DTOs. Hold business rules. |
| **Core** | Feature-agnostic infrastructure: config, DI, errors, networking, routing, security, theme, utilities, app-shell widgets, services. | Contain feature-specific logic. |
| **Shared** | Cross-feature value types, reusable design-system widgets, extensions. | Contain infrastructure or feature logic. |

## Folder conventions

```text
lib/
├── main.dart                Entry point: bootstrap, then runApp
├── app.dart                 Root widget (ProxyCareApp)
├── core/
│   ├── config/              Env: compile-time configuration and validation
│   ├── constants/           Feature-agnostic constants, one file per topic
│   ├── di/                  Core providers, root container, bootstrap
│   ├── error/               Exceptions, failures, error mapper, repository
│   │                        guard, crash reporter, global error handlers
│   ├── l10n/                ARB strings, generated localizations, error
│   │                        messages
│   ├── network/             Dio client, interceptors, network errors
│   ├── router/              GoRouter set-up
│   ├── security/            Secure storage and tokens
│   ├── services/            Other cross-cutting services
│   ├── theme/               Design-system tokens, breakpoints, ThemeData
│   ├── utils/               Pure helpers
│   └── widgets/             App-shell widgets (no product screens)
├── features/
│   └── <feature>/
│       ├── <feature>_providers.dart
│       ├── data/
│       │   ├── datasources/
│       │   ├── dto/
│       │   ├── mappers/
│       │   └── repositories/
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/
│       │   └── usecases/
│       └── presentation/
│           └── controllers/
└── shared/
    ├── extensions/
    ├── models/
    └── widgets/

test/                        Mirrors lib/
├── architecture/            Dependency-rule checks
├── core/
├── features/
├── shared/
├── fixtures/                Test data builders and sample sources
├── helpers/                 Test utilities (containers, rule checker)
└── mocks/                   mocktail mocks
```

Each `core/` and `shared/` folder has a short README describing what belongs
in it. Folders without code yet contain only that README (or a `.gitkeep`).

Naming:

- Files are `snake_case.dart`; one public type per file where practical.
- DTOs end in `Dto` (`UserDto`); mappers end in `Mapper` or are extensions
  named `<Dto>Mapper`; repository implementations end in `Impl`
  (`AuthRepositoryImpl`); controllers end in `Controller`.
- Providers end in `Provider` (`authRepositoryProvider`).

## Dependency injection

Riverpod is the only dependency-injection mechanism. There is no service
locator and no global mutable singleton.

### Where providers live

| Providers | File |
| --- | --- |
| Infrastructure (env, logger, error reporter, crash reporter, error mapper, later Dio, storage, router) | `core/di/core_providers.dart` |
| A feature's data sources, repositories and use cases | `features/<feature>/<feature>_providers.dart` |
| A feature's controllers | Next to the controller in `presentation/controllers/` |
| Root overrides | `core/di/app_container.dart` (`createAppContainer`) |

A repository provider is typed as the **domain interface**, and only the
feature's providers file names the implementation:

```dart
// features/auth/auth_providers.dart
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteSourceProvider)),
);

final signInProvider = Provider<SignIn>(
  (ref) => SignIn(ref.watch(authRepositoryProvider)),
);
```

### Provider kinds

| Kind | Use for |
| --- | --- |
| `Provider<T>` | Stateless objects: clients, data sources, repositories, use cases, derived values. |
| `NotifierProvider<N, S>` | Synchronous UI state that changes through methods. |
| `AsyncNotifierProvider<N, S>` | State loaded or changed asynchronously (most controllers). |

```dart
final visitFilterProvider =
    NotifierProvider<VisitFilterController, VisitFilter>(
  VisitFilterController.new,
);

class VisitFilterController extends Notifier<VisitFilter> {
  @override
  VisitFilter build() => VisitFilter.upcoming;

  void select(VisitFilter filter) => state = filter;
}

final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, Profile>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final result = await ref.watch(getProfileProvider).call();
    // A Failure becomes AsyncValue.error holding the AppFailure.
    return result.getOrThrow();
  }
}
```

### Lifecycle and disposal

- Infrastructure providers are **kept alive** for the whole app (the plain
  `Provider` default).
- Screen-scoped state uses **`.autoDispose`**, so it is freed when no widget
  listens any more.
- Anything holding a resource (streams, timers, clients, loggers) releases it
  in **`ref.onDispose`**, registered right after it is created:

  ```dart
  final logger = Logger(/* ... */);
  ref.onDispose(logger.close);
  ```

- Use `ref.watch` inside `build` and provider bodies so dependencies are
  rebuilt when their inputs change; use `ref.read` only inside callbacks
  (button handlers, notifier methods).
- Never store a `Ref` or `WidgetRef` outside the provider or widget it
  belongs to.

### ProviderScope and overrides

- The app runs under **one** root container, created by `bootstrap()` and
  given to `UncontrolledProviderScope` in `main.dart`. Bootstrap needs the
  container before the first frame (for example to read the error reporter),
  which is why it is created outside the widget tree.
- `envProvider` has **no default**: `createAppContainer` overrides it with
  the validated `Env`. Reading it without an override throws.
- Tests build the same container with `createTestContainer` (in
  `test/helpers/`), which calls `createAppContainer`, adds overrides and
  disposes the container after the test. Widget tests use
  `ProviderScope(overrides: [...])`.
- Override with `overrideWithValue` for ready-made fakes and `overrideWith`
  when the fake needs `ref`. Overrides are for tests and environment
  wiring, not for switching behaviour in production code.

## Feature module conventions

Build a feature from the inside out:

1. **Domain**
   - `entities/`: immutable business objects shaped by the business, not by
     the API. Freezed may be used for value equality (`freezed_annotation`
     is pure Dart); `json_annotation` may not.
   - `repositories/`: `abstract interface class AuthRepository` returning
     `Future<Result<T>>`.
   - `usecases/`: one action per class with a `call` method, depending only
     on repository interfaces.
2. **Data**
   - `dto/`: request and response classes matching the API exactly, using
     `json_serializable` (or Freezed with JSON).
   - `mappers/`: explicit conversion between DTOs and entities.
   - `datasources/`: talk to Dio or storage; return DTOs; parse bodies with
     `decodeResponse`; let transport errors propagate (Dio exceptions or
     `AppException`s).
   - `repositories/`: `AuthRepositoryImpl implements AuthRepository`; wrap
     each operation in `guardResult`, which maps infrastructure errors to an
     `AppFailure` and returns a `Result` (see [Errors](#errors)).
3. **Wiring**: `<feature>_providers.dart` registers data sources,
   repositories (typed as the interface) and use cases.
4. **Presentation**: controllers watch use-case providers and expose
   `AsyncValue` or plain state to widgets.

A feature may use another feature's **domain** layer (entities, repository
interfaces, use cases), but never its data or presentation layers.

## DTO and domain mapping

DTOs mirror the API; entities mirror the business. They change for different
reasons, so they are separate types joined by an explicit mapper:

```dart
// data/dto/user_dto.dart: the API's shape
@JsonSerializable()
class UserDto {
  const UserDto({required this.id, required this.full_name, this.phone});
  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);
  final String id;
  final String full_name;
  final String? phone;
}

// domain/entities/user.dart: the business's shape (pure Dart)
class User {
  const User({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
}

// data/mappers/user_mapper.dart: the only place both are known
extension UserDtoMapper on UserDto {
  User toEntity() => User(id: id, name: full_name, phone: phone);
}
```

Rules:

- Only `data/` imports DTOs. Repository implementations map before returning.
- Mapping is explicit and tested; no `fromJson` on entities.
- API naming, nullability and wrapper envelopes stay in DTOs. Entities
  express what the business needs (required fields are non-nullable).
- When the API changes, only the DTO and the mapper change.

## Errors

Three kinds of error, each with its own type and its own layer:

| Kind | Type | Produced by | Seen by |
| --- | --- | --- | --- |
| Infrastructure exception | `AppException` (sealed): `NetworkException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ValidationException` (field errors), `ServerException` (incl. `invalidResponse`), `TimeoutException`, `CancelledException`, `UnknownException` | `ErrorMapper` from Dio errors, HTTP statuses, the backend error envelope and serialization errors | Core and data only |
| Application failure | `AppFailure` (sealed): `NetworkFailure` (incl. timeouts), `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`, `ValidationFailure`, `ConflictFailure`, `BusinessRuleFailure`, `RateLimitedFailure`, `ServiceUnavailableFailure`, `ServerFailure`, `CancelledFailure`, `UnexpectedFailure` | Repositories, from an `AppException` (`toFailure()`) | Domain and presentation |
| Domain failure | subclasses of `DomainFailure` (an `AppFailure`) | Features, for business rules | Domain and presentation |

Programming errors (`Error`: `TypeError`, `StateError`, failed asserts) are
none of these. They are not caught by repositories; they reach the global
handlers.

### Result

`Result<T>` (`shared/models/result.dart`) is `Success<T>(value)` or
`Failure<T>(AppFailure)`. Use an exhaustive `switch`, `fold`, `map` (value),
`flatMap` (chain operations that can fail) or `getOrThrow` (in an
`AsyncNotifier`, where the thrown failure becomes `AsyncValue.error`).

### Repository convention

```dart
@override
Future<Result<Profile>> getProfile() => guardResult(
  () async => (await _remote.fetchProfile()).toEntity(),
  mapper: _errorMapper,      // errorMapperProvider
  reporter: _errorReporter,  // errorReporterProvider
);
```

- Every public repository method returns `Future<Result<T>>` and never throws
  an `AppException` or a Dio type.
- `guardResult` catches `Exception`s only. It maps them with `ErrorMapper`,
  converts them with `toFailure()`, and reports unknown failures,
  unreadable responses and 5xx failures to the `ErrorReporter`. An
  `AppFailure` thrown inside the action passes through; an `Error` is
  rethrown.
- Data sources decode bodies inside `decodeResponse(() => Dto.fromJson(json))`,
  which turns a payload of the wrong shape into
  `ServerException.invalidResponse`. Outside that call a `TypeError` stays a
  bug.
- A repository that needs a domain failure checks the backend code before
  returning, for example
  `Failure(failure: ServerFailure(code: 'SLOT_TAKEN')) => const Failure(SlotUnavailable())`.

### Backend errors

Every endpoint answers errors with the standard envelope:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "fieldErrors": { "email": ["Invalid email address"] }
  },
  "meta": { "timestamp": "2026-11-14T10:00:00Z", "correlationId": "abc-123" }
}
```

`BackendError.parse` reads `error.code`, `error.message` (logs only),
`error.fieldErrors` and `meta.correlationId`. An endpoint with a different
structure passes its own `BackendErrorParser` to `ErrorMapper` (or to one
`fromResponse` call); the default is never guessed per response. The
standard codes are `BackendErrorCode` (`VALIDATION_ERROR`, `UNAUTHENTICATED`,
`FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `BUSINESS_RULE_VIOLATION`,
`RATE_LIMITED`, `REQUEST_TIMEOUT`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`);
an unknown code is kept as a raw string.

The HTTP status is authoritative; the code only refines what the status
leaves open. Error handling never depends on the message text.

| Status | Exception → failure |
| --- | --- |
| any 4xx with field errors | `ValidationException` → `ValidationFailure` |
| 400, 422 | `ValidationException`, unless the code is `BUSINESS_RULE_VIOLATION` → `BusinessRuleFailure` |
| 401 | `UnauthorizedException` → `UnauthorizedFailure` |
| 403 | `ForbiddenException` → `ForbiddenFailure` |
| 404, 410 | `NotFoundException` → `NotFoundFailure` |
| 408, 504 | `TimeoutException` → `NetworkFailure(isTimeout: true)` |
| 409 | `ServerException` → `ConflictFailure` |
| 429 | `ServerException` → `RateLimitedFailure` |
| 503 | `ServerException` → `ServiceUnavailableFailure` |
| other 4xx | `ServerException` → by code (`BUSINESS_RULE_VIOLATION`, `CONFLICT`, `RATE_LIMITED`), else `ServerFailure` |
| other 5xx | `ServerException` → `ServerFailure` (`ServiceUnavailableFailure` if the code says so) |

### Presentation: user-facing messages

All user-facing text lives in ARB files (`lib/core/l10n/arb/`, English for
now). `UserErrorKind.of(failure)` (pure Dart) picks the message category;
`AppLocalizations.failureMessage(failure)` returns its localized text, and
`fieldErrorMessage(failure, field)` the text for a rejected form field (the
localized validation message by default; the backend's field text only when
a screen opts in, since it is not localized). Screens never show
`AppFailure.message`, backend messages, exception text or stack traces. A
cancelled operation has no message. Feature `DomainFailure`s show the
business-rule message unless the feature adds its own string.

### Crash reporting

`ErrorReporter` (`LoggerErrorReporter`) logs every unhandled error and
forwards a `CrashReport` to the vendor-independent `CrashReporter`
(`crashReporterProvider`, a `NoopCrashReporter` for the MVP; Firebase
Crashlytics is backlog LL-05). A `CrashReport` carries only the error type,
stack trace, context and whether it was fatal, never the error object or
its message, so healthcare information, patient data and tokens cannot reach
a crash-reporting service.

### Global handlers

- `FlutterError.onError` → `ErrorReporter` (context `flutter`), then the
  previous handler.
- `PlatformDispatcher.instance.onError` → `ErrorReporter` (context
  `platform`). The web engine never calls it, so:
- `runGuardedZone` wraps the whole start-up (`main.dart`) and reports
  uncaught asynchronous errors (context `zone`). Bindings are initialized
  inside the zone. Errors before the reporter exists (invalid configuration)
  go to the root zone, so a broken start-up fails loudly.
- `ErrorWidget.builder`: in release and profile builds a widget whose build
  throws renders as empty space, without exception text or stack trace; the
  error is still reported. Debug builds keep the framework's error widget.

## Application initialization

`main()` → `runGuardedZone(...)` → `bootstrap()` → `runApp`:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `Env.fromEnvironment()` reads and validates the `--dart-define` values.
   An invalid configuration throws `EnvConfigException` before anything
   else starts.
3. `createAppContainer(env:)` creates the root `ProviderContainer`, with
   `envProvider` overridden. Infrastructure providers build lazily from it.
4. `installGlobalErrorHandlers(...)` sends `FlutterError.onError` and
   `PlatformDispatcher.onError` to the `ErrorReporter` (logger by default;
   override `errorReporterProvider` for a crash-reporting service), and
   `installErrorWidgetBuilder()` keeps error details out of failed widgets
   outside debug builds.
5. `main` runs `ProxyCareApp` inside
   `UncontrolledProviderScope(container: ...)`.

Bootstrap contains no feature logic. Future infrastructure that must be ready
before the first frame (for example restoring a session from secure storage)
is added as an extra step inside `bootstrap()`.

## Shared code conventions

| Kind | Location | Rule |
| --- | --- | --- |
| Value types used across features (`Result`) | `shared/models` | Pure Dart, immutable, value equality |
| Reusable UI components | `shared/widgets` | Design-system based; no providers or feature knowledge |
| Extensions | `shared/extensions` | One file per extended type, named `<Type>X` |
| Pure helpers | `core/utils` | Stateless, unit-tested |
| Constants | `core/constants` | `abstract final class` namespaces, one file per topic |
| Common interfaces (`ErrorReporter`, `AppFailure`) | `core/error` (and the matching `core/` folder) | Interface in pure Dart; implementation registered in `core/di` |

If something is used by only one feature, it stays in that feature.
