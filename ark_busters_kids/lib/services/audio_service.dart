import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_service.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const hubBgmAsset = 'audio/bgm/bgm-top.mp3';
  static const battleBgmAsset = 'audio/bgm/bgm-battle.mp3';
  static const hubBgmVolume = 0.4;
  static const battleBgmVolume = 0.35;

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();

  bool _ready = false;
  bool _bgmOn = true;

  bool get isBgmOn => _bgmOn;

  Future<void> init() async {
    if (_ready) return;

    await _bgm.setReleaseMode(ReleaseMode.loop);
    await _bgm.setVolume(hubBgmVolume);
    await _bgm.setPlayerMode(PlayerMode.mediaPlayer);
    await _sfx.setPlayerMode(PlayerMode.lowLatency);
    await _voice.setPlayerMode(PlayerMode.mediaPlayer);

    final prefs = await SharedPreferences.getInstance();
    _bgmOn = prefs.getString('ark_bgm') != '0';
    _ready = true;
  }

  Future<void> playHubBgm() async {
    await init();
    if (!_bgmOn) return;
    try {
      await _bgm.stop();
      await _bgm.setVolume(hubBgmVolume);
      await _bgm.play(AssetSource(hubBgmAsset));
    } catch (e, st) {
      debugPrint('playHubBgm failed: $e\n$st');
    }
  }

  Future<void> playBattleBgm() async {
    await init();
    if (!_bgmOn) return;
    try {
      await _bgm.stop();
      await _bgm.setVolume(battleBgmVolume);
      await _bgm.play(AssetSource(battleBgmAsset));
    } catch (e, st) {
      debugPrint('playBattleBgm failed: $e\n$st');
    }
  }

  Future<void> toggleBgm() async {
    await init();
    _bgmOn = !_bgmOn;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ark_bgm', _bgmOn ? '1' : '0');
    if (_bgmOn) {
      await playHubBgm();
    } else {
      await stopBgm();
    }
  }

  Future<void> stopBgm() async {
    await init();
    await _bgm.stop();
  }

  /// Web music/{name}.mp3 — respects ark_se
  Future<void> playSfx(String name, {double volume = 0.75}) async {
    await init();
    if (!await ProgressService.instance.isSeOn()) return;
    try {
      await _sfx.stop();
      await _sfx.setVolume(volume);
      await _sfx.play(AssetSource('audio/sfx/$name.mp3'));
    } catch (e) {
      debugPrint('playSfx $name failed: $e');
    }
  }

  /// Asset path without assets/ prefix. Respects ark_voice.
  Future<void> playVoiceAsset(String? assetPath) async {
    if (assetPath == null || assetPath.isEmpty) return;
    await init();
    if (!await ProgressService.instance.isVoiceOn()) return;
    try {
      await _voice.stop();
      await _voice.setVolume(1);
      await _voice.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('playVoiceAsset failed: $e');
    }
  }
}
