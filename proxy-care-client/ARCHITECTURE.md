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
| Types the domain uses (`shared/models`, `core/config`, `Failure`, `ErrorReporter`) are pure Dart | Yes |
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
│   ├── error/               Failure, ErrorReporter, global error handlers
│   ├── network/             Dio client, interceptors, network errors
│   ├── router/              GoRouter set-up
│   ├── security/            Secure storage and tokens
│   ├── services/            Other cross-cutting services
│   ├── theme/               Design-system tokens and ThemeData
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
| Infrastructure (env, logger, error reporter, later Dio, storage, router) | `core/di/core_providers.dart` |
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
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
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
   - `datasources/`: talk to Dio or storage; return DTOs; throw on
     transport errors.
   - `repositories/`: `AuthRepositoryImpl implements AuthRepository`; call
     data sources, map DTOs to entities, catch expected errors and return
     `Err(failure)`.
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

- **Expected failures** (offline, validation, rejected payment) are values:
  repositories and use cases return `Result<T>`, either `Ok` or
  `Err(Failure)`. Concrete `Failure` subclasses are added with the
  error-handling layer.
- **Unexpected errors** (bugs) throw. Anything that escapes is caught by the
  global handlers and sent to the `ErrorReporter`.

## Application initialization

`main()` → `bootstrap()` → `runApp`:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `Env.fromEnvironment()` reads and validates the `--dart-define` values.
   An invalid configuration throws `EnvConfigException` before anything
   else starts.
3. `createAppContainer(env:)` creates the root `ProviderContainer`, with
   `envProvider` overridden. Infrastructure providers build lazily from it.
4. `installGlobalErrorHandlers(...)` sends `FlutterError.onError` and
   `PlatformDispatcher.onError` to the `ErrorReporter` (logger by default;
   override `errorReporterProvider` for a crash-reporting service).
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
| Common interfaces (`ErrorReporter`, `Failure`) | `core/error` (and the matching `core/` folder) | Interface in pure Dart; implementation registered in `core/di` |

If something is used by only one feature, it stays in that feature.
