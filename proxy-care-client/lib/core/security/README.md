# core/security

Security infrastructure: secure storage (`flutter_secure_storage`) wrappers
and token persistence.

- Callers depend on an interface (for example `TokenStore`), never on
  `FlutterSecureStorage` directly, so tests can substitute fakes.
- Never log secrets or tokens.
