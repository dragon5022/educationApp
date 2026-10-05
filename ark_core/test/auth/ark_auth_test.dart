import 'package:ark_core/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const spec = ProgressSyncSpec([SyncKey.prefix('ark_best_', MergeRule.max)]);
const email = 'ark001@students.ark-busters.app';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Firebase unavailable', () {
    test('init with null FirebaseOptions → unavailable, no throw', () async {
      final auth = ArkAuth();
      await auth.init(appId: 'kids', firebaseOptions: null, sync: spec);
      expect(auth.status, ArkAuthStatus.unavailable);
      expect(auth.isAvailable, isFalse);
      expect(auth.isSignedIn, isFalse);
      expect(auth.currentId, isNull);
      expect(auth.sync, isNull);
      final r = await auth.login('ark001', 'pw');
      expect(r.error, ArkAuthError.unavailable);
      await auth.logout(); // no-op
      expect(await auth.syncNow(), isNull);
      auth.notifyProgressChanged(); // no-op
      auth.dispose();
    });

    test('initWithBackends(backend: null) → unavailable', () async {
      final auth = ArkAuth();
      await auth.initWithBackends(appId: 'kids', backend: null);
      expect(auth.status, ArkAuthStatus.unavailable);
      auth.dispose();
    });
  });

  group('ID → email', () {
    final auth = ArkAuth();
    test('maps, normalizes and validates', () {
      expect(auth.emailForId('ark001'), email);
      expect(auth.emailForId('  ARK001 '), email);
      expect(auth.emailForId('ａｒｋ００１'), email); // full-width
      expect(auth.emailForId('teacher@example.com'), 'teacher@example.com');
      expect(auth.emailForId(''), isNull);
      expect(auth.emailForId('あいう'), isNull);
      expect(auth.emailForId('a b'), isNull);
      expect(auth.idForEmail(email), 'ark001');
      expect(auth.idForEmail('teacher@example.com'), 'teacher@example.com');
    });

    test('custom domain', () async {
      final a = ArkAuth();
      await a.initWithBackends(
        appId: 'kids',
        backend: FakeAuthBackend(),
        config: const ArkAuthConfig(idDomain: 'juku.example'),
        observeLifecycle: false,
      );
      expect(a.emailForId('s1'), 's1@juku.example');
      a.dispose();
    });
  });

  group('with fake backend', () {
    late FakeAuthBackend backend;
    late FakeRemote remote;
    late ArkAuth auth;

    setUp(() async {
      backend = FakeAuthBackend(
        accounts: {email: 'secret1', 'ark002@students.ark-busters.app': 'pw2'},
        disabled: {'ark002@students.ark-busters.app'},
      );
      remote = FakeRemote();
      auth = ArkAuth();
      await auth.initWithBackends(
        appId: 'kids',
        backend: backend,
        remote: remote,
        sync: spec,
      );
    });

    tearDown(() => auth.dispose());

    test('starts signed out', () {
      expect(auth.status, ArkAuthStatus.signedOut);
      expect(auth.isAvailable, isTrue);
    });

    test('login errors map to ArkAuthError', () async {
      expect(
        (await auth.login('ark001', 'bad')).error,
        ArkAuthError.wrongIdOrPassword,
      );
      expect((await auth.login('ark002', 'pw2')).error, ArkAuthError.disabled);
      expect((await auth.login('ｘ ｙ', 'pw')).error, ArkAuthError.invalidId);
      backend.offline = true;
      expect(
        (await auth.login('ark001', 'secret1')).error,
        ArkAuthError.network,
      );
      expect(auth.isSignedIn, isFalse);
    });

    test('every error has a Japanese message', () {
      for (final e in ArkAuthError.values) {
        expect(ArkAuthTexts.kids.error(e), isNotEmpty);
        expect(ArkAuthTexts.teen.error(e), isNotEmpty);
      }
    });

    test('login → syncs progress; logout keeps device progress', () async {
      final p = await SharedPreferences.getInstance();
      await p.setInt('ark_best_talk', 42);
      final r = await auth.login('ARK001', 'secret1');
      expect(r.ok, isTrue);
      expect(backend.lastEmail, email);
      expect(auth.isSignedIn, isTrue);
      expect(auth.currentId, 'ark001');
      await auth.syncNow();
      final uid = auth.user!.uid;
      expect(remote.doc(uid, 'kids')['ark_best_talk']!.value, 42);

      await p.setInt('ark_best_talk', 50);
      await auth.logout();
      expect(auth.status, ArkAuthStatus.signedOut);
      expect(auth.currentId, isNull);
      // logout flushed the last change and kept local data
      expect(remote.doc(uid, 'kids')['ark_best_talk']!.value, 50);
      expect(p.getInt('ark_best_talk'), 50);
    });
  });

  test('Firebase error codes map to ArkAuthError', () {
    expect(
      mapFirebaseAuthCode('invalid-credential'),
      ArkAuthError.wrongIdOrPassword,
    );
    expect(mapFirebaseAuthCode('user-disabled'), ArkAuthError.disabled);
    expect(mapFirebaseAuthCode('network-request-failed'), ArkAuthError.network);
    expect(
      mapFirebaseAuthCode('too-many-requests'),
      ArkAuthError.tooManyAttempts,
    );
    expect(mapFirebaseAuthCode('whatever'), ArkAuthError.unknown);
  });
}
