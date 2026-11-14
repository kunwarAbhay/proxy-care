# core/network

HTTP infrastructure shared by every feature: the configured Dio client,
interceptors (auth header, logging, error mapping) and network error types.

- Built from `Env.apiBaseUrl`; never hard-code URLs.
- Exposed to features only through providers registered in `core/di`.
- Dio errors are translated by `core/error/error_mapper.dart`; repositories
  return them as `AppFailure`s, so Dio never reaches the domain layer.
- Must not know about any specific feature or endpoint.
