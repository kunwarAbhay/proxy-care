# Security

Client-side security guarantees and the requirements they place on the
backend. The client is never a security boundary: every protected resource
must be checked by the Spring Boot API.

## Token storage guarantees

- The only credential the client persists is the Supabase session (access
  token, refresh token, expiry, user), stored as **one** entry by
  `SecureSupabaseLocalStorage` through `SecureKeyValueStore`
  (`flutter_secure_storage` 11.2.0). PKCE code verifiers use the same store.
- Tokens are never written to SharedPreferences, files, logs or crash
  reports. `supabase_flutter` depends on `shared_preferences` for its
  default storage, but the app always passes its own secure storage, and an
  architecture test fails if any app code imports `shared_preferences` or
  uses the SDK's default storage classes.
- No insecure fallback: a storage failure is reported; reads fall back to
  "no session" (the user signs in again), writes and deletes fail.
- Session invalidation and session expiry delete the stored session.
- Tokens are not exposed to UI code: widgets get `AuthenticationState`,
  which carries no tokens. The access token is only read by the API client.

## Android (when the Android target is added)

The app is web-only for now (decision 4 is deferred), so these settings are
in code and must be completed in `android/` when that folder exists:

- `flutter_secure_storage` 10+ no longer uses Jetpack
  `EncryptedSharedPreferences`. The app sets AES-GCM for both the key cipher
  (the AES key lives in the **Android Keystore**) and the storage cipher
  (`FlutterSecureKeyValueStore.androidOptions`).
- `resetOnError` (the plugin default, kept) erases entries whose Keystore key
  can no longer unwrap them; the user signs in again instead of the app
  failing on every start.
- **Backups:** Keystore keys never leave the device, so backed-up ciphertext
  cannot be decrypted after a restore and can cause `Failed to unwrap key`
  errors. In `AndroidManifest.xml` set `android:allowBackup="false"`, or keep
  backups and exclude the plugin's preferences file with
  `android:fullBackupContent` (API ≤ 30) and `android:dataExtractionRules`
  (API 31+) rules that exclude the `FlutterSecureStorage` shared preferences.

## iOS (when the iOS target is added)

- Entries are Keychain items with accessibility
  `first_unlock_this_device` (`FlutterSecureKeyValueStore.iosOptions`):
  readable after the device has been unlocked once since boot (so a refresh
  can run in the background), never synced to iCloud Keychain
  (`synchronizable: false`) and not restored to another device.
- **Uninstall:** iOS keeps Keychain items after the app is deleted. A
  reinstall could find an old session. When the iOS target is added, clear
  the secure store on the first launch after installation (using a
  non-secret "first run" marker); the Supabase session would otherwise be
  restored and then refreshed or rejected by the server.

## Web (current target)

`flutter_secure_storage` on web encrypts values with WebCrypto and keeps them
in the browser's storage, with the key in the same browser. This was chosen
knowingly and is **weaker** than the mobile stores: any script running on the
page origin (for example through an XSS flaw or a compromised dependency) can
use the stored session. It also works only on HTTPS or localhost.
Mitigations to apply when deploying: a strict Content Security Policy, HTTP
Strict Transport Security, no third-party scripts on the app origin, and the
1-hour access-token expiry with refresh-token reuse detection left on.

## Sensitive logging restrictions

- `LoggingInterceptor` logs only method, path, status, duration and
  correlation ID. No hosts, query values, headers or bodies; debug builds add
  masked headers and query parameter names only.
- `LogRedactor` masks `Authorization`, cookies, tokens (access, refresh, id),
  passwords, secrets, API keys, OTPs and PINs, identity and payment details,
  contact details and health fields.
- The Supabase SDK's debug logging is disabled (`debug: false`).
- Crash reports carry only the error type, stack trace and context, never the
  error message or object.
- `AuthenticatedUser.toString()` prints the user ID only;
  `SecureStorageException` names the key, never the value.

## Environment configuration

- `config/env/*.json` holds non-sensitive values only: the API URL, the
  Supabase URL and the Supabase **publishable** key (safe to ship; Row Level
  Security limits what it can reach).
- `Env` rejects secret keys (`sb_secret_…`) and legacy service-role JWTs, so a
  build containing one fails. Secret keys, the JWT secret, database
  credentials, payment secrets and signing credentials stay in backend
  infrastructure or CI secret management.
- `--dart-define` values are compiled into the app and readable by anyone
  with the binary; they are not secret storage.

## Backend JWT validation requirements (Spring Boot)

The client sends the Supabase access token as `Authorization: Bearer …` on
every API request that is not public. The backend must, on every request:

1. Verify the signature against the project's JWKS
   (`https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json`), which
   requires **asymmetric** JWT signing keys (ES256/RS256) in the Supabase
   project. Match the token's `kid` and `alg`; refresh the cached JWKS at
   least every 10 minutes and on an unknown `kid` (key rotation).
2. Check `iss` = `https://<project-ref>.supabase.co/auth/v1`,
   `aud` = `authenticated`, and that `exp` is in the future.
3. Use `sub` as the user ID. Take roles only from server-controlled claims
   (`app_metadata` or a Custom Access Token Hook), never from
   `user_metadata`, which users can edit.
4. Enforce every permission on the server; client authorization is a hint.
5. For the most sensitive actions, also check that the token's `session_id`
   still exists, because sign-out does not invalidate already-issued access
   tokens before they expire.
6. Answer an invalid or expired token with 401 and a missing permission with
   403 (the client recovers once from a 401 and never retries a 403), using
   the standard error envelope.

These are assumptions about the backend; no endpoint or authentication
contract is defined in this repository.
