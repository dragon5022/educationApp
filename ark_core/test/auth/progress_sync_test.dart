import 'package:ark_core/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Keys as ARK BUSTERS KIDS stores them.
const kidsSpec = ProgressSyncSpec([
  SyncKey('ark_name', MergeRule.lastWriteWins),
  SyncKey('ark_friends', MergeRule.union),
  SyncKey('ark_story_seen', MergeRule.max),
  SyncKey.prefix('ark_cards_', MergeRule.union),
  SyncKey.prefix('ark_s_', MergeRule.max),
  SyncKey.prefix('ark_best_', MergeRule.max),
  SyncKey.prefix('lb2_', MergeRule.max),
  SyncKey.prefix('eb2_', MergeRule.max),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRemote remote;
  var now = 1000;

  ProgressSync makeSync({
    AccountSwitchPolicy policy =
        AccountSwitchPolicy.replaceOtherAccountsProgress,
  }) => ProgressSync(
    appId: 'kids',
    spec: kidsSpec,
    remote: remote,
    local: LocalProgressStore(),
    switchPolicy: policy,
    clock: () => now,
  );

  setUp(() {
    remote = FakeRemote();
    now = 1000;
  });

  test('guest progress is uploaded on first login', () async {
    SharedPreferences.setMockInitialValues({
      'ark_name': 'ken',
      'ark_friends': '["vocamon"]',
      'ark_s_vocamon': 12,
      'lb2_g5_0': '80',
      'ark_se': '0', // not in spec → stays local only
    });
    final s = makeSync();
    final r = await s.start('u1');
    expect(r.state, SyncState.synced);
    final doc = remote.doc('u1', 'kids');
    expect(doc.keys, {'ark_name', 'ark_friends', 'ark_s_vocamon', 'lb2_g5_0'});
    expect(doc['ark_s_vocamon']!.value, 12);
    expect(doc['lb2_g5_0']!.value, '80');
    s.dispose();
  });

  test('new device (reinstall) restores cloud progress', () async {
    remote.doc('u1', 'kids').addAll({
      'ark_name': const SyncEntry('ken', 500),
      'ark_cards_lismon': const SyncEntry('[3,7]', 500),
      'ark_best_talk': const SyncEntry(90, 500),
    });
    SharedPreferences.setMockInitialValues({});
    final s = makeSync();
    final r = await s.start('u1');
    expect(r.pulled, {'ark_name', 'ark_cards_lismon', 'ark_best_talk'});
    final p = await SharedPreferences.getInstance();
    expect(p.getString('ark_name'), 'ken');
    expect(p.getString('ark_cards_lismon'), '[3,7]');
    expect(p.getInt('ark_best_talk'), 90);
    expect(remote.saves, 0);
    s.dispose();
  });

  test('merges both ways and keeps local types', () async {
    remote.doc('u1', 'kids').addAll({
      'ark_friends': const SyncEntry('["lismon"]', 1),
      'ark_s_vocamon': const SyncEntry(20, 1),
      'eb2_g5_endless': const SyncEntry('15', 1),
      'ark_name': const SyncEntry('cloud', 1),
    });
    SharedPreferences.setMockInitialValues({
      'ark_friends': '["vocamon"]',
      'ark_s_vocamon': 5,
      'eb2_g5_endless': '40',
      'ark_name': 'device',
    });
    now = 2000; // local edits are newer than the cloud's
    final s = makeSync();
    await s.start('u1');
    final p = await SharedPreferences.getInstance();
    expect(p.getString('ark_friends'), '["lismon","vocamon"]');
    expect(p.getInt('ark_s_vocamon'), 20);
    expect(p.getString('eb2_g5_endless'), '40');
    expect(p.getString('ark_name'), 'device');
    final doc = remote.doc('u1', 'kids');
    expect(doc['ark_friends']!.value, '["lismon","vocamon"]');
    expect(doc['eb2_g5_endless']!.value, '40');
    expect(doc['ark_name']!.value, 'device');
    s.dispose();
  });

  test('a newer cloud name wins over an unchanged local name', () async {
    SharedPreferences.setMockInitialValues({'ark_name': 'old'});
    final s = makeSync();
    await s.start('u1'); // records 'old' @1000
    // Another device renames later.
    remote.doc('u1', 'kids')['ark_name'] = const SyncEntry('new', 5000);
    now = 6000;
    await s.syncNow();
    final p = await SharedPreferences.getInstance();
    expect(p.getString('ark_name'), 'new');
    // …and a later local rename wins again.
    await p.setString('ark_name', 'mine');
    now = 7000;
    await s.syncNow();
    expect(remote.doc('u1', 'kids')['ark_name']!.value, 'mine');
    expect(remote.doc('u1', 'kids')['ark_name']!.updatedAt, 7000);
    s.dispose();
  });

  test(
    'offline: local progress untouched, error state, then recovers',
    () async {
      SharedPreferences.setMockInitialValues({'ark_best_talk': 50});
      remote.offline = true;
      final s = makeSync();
      final r = await s.start('u1');
      expect(r.state, SyncState.error);
      expect(s.state, SyncState.error);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('ark_best_talk'), 50);
      remote.offline = false;
      final r2 = await s.syncNow();
      expect(r2.state, SyncState.synced);
      expect(remote.doc('u1', 'kids')['ark_best_talk']!.value, 50);
      s.dispose();
    },
  );

  test('queued (unacknowledged) writes report pendingOffline', () async {
    SharedPreferences.setMockInitialValues({'ark_best_talk': 50});
    remote.queueWrites = true;
    final s = makeSync();
    final r = await s.start('u1');
    expect(r.state, SyncState.pendingOffline);
    expect(r.ok, isTrue);
    s.dispose();
  });

  test(
    'switching to another account replaces that account-owned data',
    () async {
      remote.doc('u2', 'kids')['ark_best_talk'] = const SyncEntry(7, 1);
      SharedPreferences.setMockInitialValues({
        'ark_best_talk': 99,
        'ark_name': 'aya',
        'ark_se': '1',
      });
      final s = makeSync();
      await s.start('u1');
      await s.stop();
      await s.start('u2');
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('ark_best_talk'), 7); // u2's own record
      expect(p.containsKey('ark_name'), isFalse); // u1's name removed
      expect(p.getString('ark_se'), '1'); // non-synced settings untouched
      expect(remote.doc('u1', 'kids')['ark_best_talk']!.value, 99); // kept
      expect(remote.doc('u2', 'kids')['ark_best_talk']!.value, 7);
      s.dispose();
    },
  );

  test('alwaysMerge policy merges into the next account', () async {
    SharedPreferences.setMockInitialValues({'ark_best_talk': 99});
    final s = makeSync(policy: AccountSwitchPolicy.alwaysMerge);
    await s.start('u1');
    await s.stop();
    await s.start('u2');
    expect(remote.doc('u2', 'kids')['ark_best_talk']!.value, 99);
    s.dispose();
  });

  test('same account logging in again merges (no replace)', () async {
    SharedPreferences.setMockInitialValues({'ark_best_talk': 10});
    final s = makeSync();
    await s.start('u1');
    await s.stop();
    final p = await SharedPreferences.getInstance();
    await p.setInt('ark_best_talk', 30); // played offline while logged out
    await s.start('u1');
    expect(remote.doc('u1', 'kids')['ark_best_talk']!.value, 30);
    s.dispose();
  });

  test('notifyChanged debounces into one sync', () async {
    SharedPreferences.setMockInitialValues({'ark_best_talk': 1});
    final s = ProgressSync(
      appId: 'kids',
      spec: kidsSpec,
      remote: remote,
      debounce: const Duration(milliseconds: 20),
      clock: () => now,
    );
    await s.start('u1');
    final before = remote.saves;
    final p = await SharedPreferences.getInstance();
    await p.setInt('ark_best_talk', 2);
    s.notifyChanged();
    s.notifyChanged();
    s.notifyChanged();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remote.saves, before + 1);
    expect(remote.doc('u1', 'kids')['ark_best_talk']!.value, 2);
    s.dispose();
  });

  test('notifyChanged does nothing when signed out', () async {
    final s = makeSync();
    s.notifyChanged();
    expect((await s.syncNow()).state, SyncState.idle);
    s.dispose();
  });
}
