/// Login with school-issued IDs (Firebase Auth) and cloud progress sync
/// (Cloud Firestore). Optional at runtime: without Firebase options the
/// module reports “unavailable” and the app plays offline.
///
/// See `doc/AUTH.md`.
library;

export 'src/auth/account_row.dart';
export 'src/auth/ark_auth.dart';
export 'src/auth/auth_backend.dart';
export 'src/auth/auth_theme.dart';
export 'src/auth/firebase_backend.dart'
    show FirebaseArkAuthBackend, FirestoreProgressRemote, mapFirebaseAuthCode;
export 'src/auth/login_sheet.dart';
export 'src/auth/merge_rules.dart';
export 'src/auth/progress_sync.dart';
