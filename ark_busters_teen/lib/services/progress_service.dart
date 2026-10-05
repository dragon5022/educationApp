import 'package:ark_core/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_keys.dart';

/// Local progress (SharedPreferences). All key names live in [ProgressKeys].
class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<bool> isBgmOn() async => (await _p).getString(ProgressKeys.bgm) != '0';

  Future<void> setBgmOn(bool on) async =>
      (await _p).setString(ProgressKeys.bgm, on ? '1' : '0');

  Future<int?> bestScore(String page, String level) async =>
      (await _p).getInt(ProgressKeys.best(page, level));

  Future<String?> bestRank(String page, String level) async =>
      (await _p).getString(ProgressKeys.rank(page, level));

  /// Records a finished game; returns true when it is a new best score.
  Future<bool> recordGame({
    required String page,
    required String level,
    required int score,
    required String rank,
  }) async {
    final p = await _p;
    await p.setInt(ProgressKeys.plays(page), (p.getInt(ProgressKeys.plays(page)) ?? 0) + 1);
    // Schedule a cloud sync (no-op when logged out / login unavailable).
    ArkAuth.instance.notifyProgressChanged();
    final best = p.getInt(ProgressKeys.best(page, level));
    if (best != null && score <= best) return false;
    await p.setInt(ProgressKeys.best(page, level), score);
    await p.setString(ProgressKeys.rank(page, level), rank);
    return best != null;
  }
}
