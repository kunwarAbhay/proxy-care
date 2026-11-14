/// The networking layer's view of the signed-in session.
///
/// `AuthInterceptor` asks it for the access token to attach and, after a
/// 401, asks it to refresh. How tokens are stored and refreshed (secure
/// storage, a single shared refresh for concurrent 401s, sign-out when the
/// refresh fails) is the session's job and arrives with the authentication
/// milestone. Until then [SignedOutSession] is used.
abstract interface class AuthenticationSession {
  /// The current access token, or null when signed out.
  Future<String?> accessToken();

  /// Obtains a new access token after the backend rejected [rejectedToken]
  /// with a 401. Returns the new token, or null when the session cannot be
  /// renewed (the user must sign in again).
  ///
  /// The refresh call itself must be sent with `ApiRequestOptions(
  /// skipAuth: true)` so the interceptor does not intercept it.
  Future<String?> refreshAccessToken({required String? rejectedToken});
}

/// A session that is never signed in: no token is attached and nothing can
/// be refreshed.
final class SignedOutSession implements AuthenticationSession {
  /// Creates a signed-out session.
  const SignedOutSession();

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<String?> refreshAccessToken({required String? rejectedToken}) async =>
      null;
}
