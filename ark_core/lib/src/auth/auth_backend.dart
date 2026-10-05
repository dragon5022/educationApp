/// Minimal user info ark_core needs: the Firebase uid and the login email.
class ArkUser {
  const ArkUser({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// Why a login failed.
enum ArkAuthError {
  /// ID or password is wrong (Firebase does not say which).
  wrongIdOrPassword,

  /// The school disabled this account.
  disabled,

  /// No internet connection.
  network,

  /// Too many failed attempts; try again later.
  tooManyAttempts,

  /// The ID has characters that cannot be used.
  invalidId,

  /// Login is not available in this build (Firebase not configured).
  unavailable,
  unknown,
}

class ArkAuthException implements Exception {
  const ArkAuthException(this.error, [this.code]);

  final ArkAuthError error;

  /// Raw backend code, for logs only.
  final String? code;

  @override
  String toString() => 'ArkAuthException($error, $code)';
}

/// Sign-in backend (Firebase Auth in production, a fake in tests).
abstract class ArkAuthBackend {
  ArkUser? get currentUser;

  /// Emits the current user and every change (including restored sessions).
  Stream<ArkUser?> userChanges();

  /// Throws [ArkAuthException] on failure.
  Future<ArkUser> signIn(String email, String password);

  Future<void> signOut();
}
