import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_backend.dart';
import 'merge_rules.dart';
import 'progress_sync.dart';

/// [ArkAuthBackend] on Firebase Auth (email/password).
class FirebaseArkAuthBackend implements ArkAuthBackend {
  FirebaseArkAuthBackend([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static ArkUser? _map(User? u) =>
      u == null ? null : ArkUser(uid: u.uid, email: u.email ?? '');

  @override
  ArkUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<ArkUser?> userChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<ArkUser> signIn(String email, String password) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _map(c.user)!;
    } on FirebaseAuthException catch (e) {
      throw ArkAuthException(mapFirebaseAuthCode(e.code), e.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Maps Firebase Auth error codes to [ArkAuthError].
ArkAuthError mapFirebaseAuthCode(String code) => switch (code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-email' ||
  'INVALID_LOGIN_CREDENTIALS' => ArkAuthError.wrongIdOrPassword,
  'user-disabled' => ArkAuthError.disabled,
  'network-request-failed' => ArkAuthError.network,
  'too-many-requests' => ArkAuthError.tooManyAttempts,
  'operation-not-allowed' ||
  'configuration-not-found' => ArkAuthError.unavailable,
  _ => ArkAuthError.unknown,
};

/// [ProgressRemote] on Cloud Firestore: `users/{uid}/apps/{appId}` =
/// `{schema: 1, entries: {key: {v, t}}, updatedAt: <server time>}`.
class FirestoreProgressRemote implements ProgressRemote {
  FirestoreProgressRemote([
    FirebaseFirestore? db,
    this.ackTimeout = const Duration(seconds: 8),
  ]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// How long to wait for the server before treating a write as queued.
  final Duration ackTimeout;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String appId) =>
      _db.collection('users').doc(uid).collection('apps').doc(appId);

  @override
  Future<Map<String, SyncEntry>> load(String uid, String appId) async {
    final snap = await _doc(uid, appId).get();
    final entries = snap.data()?['entries'];
    final out = <String, SyncEntry>{};
    if (entries is Map) {
      entries.forEach((k, v) {
        final e = SyncEntry.fromMap(v);
        if (k is String && e != null) out[k] = e;
      });
    }
    return out;
  }

  @override
  Future<bool> save(
    String uid,
    String appId,
    Map<String, SyncEntry> entries,
  ) async {
    // set(merge) with a nested map treats keys literally (no dotted paths) and
    // leaves other entries in place.
    final write = _doc(uid, appId).set({
      'schema': 1,
      'entries': {for (final e in entries.entries) e.key: e.value.toMap()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      await write.timeout(ackTimeout);
      return true;
    } on TimeoutException {
      // Offline: the write sits in Firestore's persistent queue and is sent
      // automatically once online. Surface later rejections nowhere — the
      // next sync re-merges anyway.
      unawaited(write.catchError((_) {}));
      return false;
    }
  }
}
