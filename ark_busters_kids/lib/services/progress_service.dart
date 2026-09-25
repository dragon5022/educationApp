import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/progress/progress_keys.dart';

class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  SharedPreferences? _prefs;
  final _rng = Random();

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String> getPlayerName() async =>
      (await _p).getString(ProgressKeys.playerName) ?? '';

  Future<void> setPlayerName(String name) async {
    final n = name.trim();
    await (await _p).setString(
      ProgressKeys.playerName,
      n.length > 12 ? n.substring(0, 12) : n,
    );
  }

  Future<bool> isSeOn() async =>
      (await _p).getString(ProgressKeys.seEnabled) != '0';

  Future<void> setSeOn(bool on) async =>
      (await _p).setString(ProgressKeys.seEnabled, on ? '1' : '0');

  Future<bool> isVoiceOn() async =>
      (await _p).getString(ProgressKeys.voiceEnabled) != '0';

  Future<void> setVoiceOn(bool on) async =>
      (await _p).setString(ProgressKeys.voiceEnabled, on ? '1' : '0');

  Future<int> bestScore(String key) async => (await _p).getInt(key) ?? 0;

  Future<void> setBestIfHigher(String key, int score) async {
    final cur = await bestScore(key);
    if (score > cur) await (await _p).setInt(key, score);
  }

  Future<List<String>> friends() async {
    final raw = (await _p).getString(ProgressKeys.friends);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> befriend(String monsterKey) async {
    final list = await friends();
    if (list.contains(monsterKey)) return;
    list.add(monsterKey);
    await (await _p).setString(ProgressKeys.friends, jsonEncode(list));
  }

  Future<int> sRankCount(String monsterKey) async =>
      (await _p).getInt(ProgressKeys.sRankCount(monsterKey)) ?? 0;

  Future<void> addSRank(String monsterKey) async {
    final n = await sRankCount(monsterKey);
    await (await _p).setInt(ProgressKeys.sRankCount(monsterKey), n + 1);
    // Award pose progress like web: floor(S/10) poses, weighted draw 1–30
    final poses = await cards(monsterKey);
    final target = ((n + 1) ~/ 10).clamp(0, 30);
    while (poses.length < target) {
      final id = _rng.nextInt(30) + 1;
      if (!poses.contains(id)) poses.add(id);
    }
    await (await _p).setString(
      ProgressKeys.cards(monsterKey),
      jsonEncode(poses),
    );
  }

  Future<List<int>> cards(String monsterKey) async {
    final raw = (await _p).getString(ProgressKeys.cards(monsterKey));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).map((e) => e as int).toList();
    } catch (_) {
      return [];
    }
  }
}
