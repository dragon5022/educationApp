import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'progress_service.dart';

/// BGM and sound effects, mirroring the web pages:
///
/// * BGM `music/bgm.mp3`, looped at volume 0.4, starts on the first tap
///   (web: first click on the top page / START on a stage) and is toggled by
///   the round speaker button.
/// * Files: start.mp3 (START / もう一度), correct.mp3 (correct answer),
///   gameover.mp3 (result without lives).
/// * Web Audio synth sounds pre-rendered by tools/gen_tones.py:
///   tick, wrong, beep800, beep1200, boom, victory.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _bgmAsset = 'audio/bgm.mp3';
  static const _bgmVolume = 0.4;

  final AudioPlayer _bgm = AudioPlayer();
  final Map<String, AudioPlayer> _sfx = {};

  /// 詩・奏 character lines (assets/audio/charvoice); own player so a line
  /// never cuts an effect and a new line replaces the previous one.
  final AudioPlayer _char = AudioPlayer();

  /// Speaker button state (web `__bgmOn`, default on).
  final ValueNotifier<bool> bgmOn = ValueNotifier(true);

  bool _ready = false;
  bool _started = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    bgmOn.value = await ProgressService.instance.isBgmOn();
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (e) {
      debugPrint('bgm init failed: $e');
    }
  }

  /// Web `startBGM()`: starts the loop once (no-op if already playing).
  Future<void> startBgm() async {
    await init();
    if (!bgmOn.value || _started) return;
    _started = true;
    try {
      await _bgm.setVolume(_bgmVolume);
      await _bgm.play(AssetSource(_bgmAsset));
    } catch (e) {
      _started = false;
      debugPrint('bgm failed: $e');
    }
  }

  /// Web `toggleBGM()`.
  Future<void> toggleBgm() async {
    await init();
    bgmOn.value = !bgmOn.value;
    await ProgressService.instance.setBgmOn(bgmOn.value);
    if (bgmOn.value) {
      _started = false;
      await startBgm();
    } else {
      _started = false;
      try {
        await _bgm.pause();
      } catch (_) {}
    }
  }

  /// App went to the background / came back.
  Future<void> pauseBgm() async {
    try {
      await _bgm.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!bgmOn.value || !_started) return;
    try {
      await _bgm.resume();
    } catch (_) {}
  }

  // ------------------------------------------------------------- effects

  Future<void> playStart() => _effect('audio/start.mp3');
  Future<void> playCorrect() => _effect('audio/correct.mp3');
  Future<void> playLose() => _effect('audio/gameover.mp3');
  Future<void> playTick() => _effect('audio/sfx/tick.wav');
  Future<void> playWrong() => _effect('audio/sfx/wrong.wav');
  Future<void> playBeep(bool go) =>
      _effect(go ? 'audio/sfx/beep1200.wav' : 'audio/sfx/beep800.wav');
  Future<void> playBoom() => _effect('audio/sfx/boom.wav');
  Future<void> playVictory() => _effect('audio/sfx/victory.wav');

  /// Plays `audio/charvoice/<chara>_<line>.mp3` after [delay] (so it follows
  /// the effect it reacts to). Lines per character: see the README; a
  /// missing clip is skipped silently.
  Future<void> playCharVoice(String chara, String line, {Duration delay = Duration.zero}) async {
    await init();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    try {
      await _char.stop();
      await _char.play(AssetSource('audio/charvoice/${chara}_$line.mp3'), volume: 1);
    } catch (e) {
      debugPrint('charvoice ${chara}_$line failed: $e');
    }
  }

  Future<void> _effect(String asset) async {
    await init();
    try {
      final p = _sfx.putIfAbsent(asset, () {
        final p = AudioPlayer();
        p.setPlayerMode(PlayerMode.lowLatency);
        p.setReleaseMode(ReleaseMode.stop);
        return p;
      });
      await p.stop();
      await p.play(AssetSource(asset), volume: 1);
    } catch (e) {
      debugPrint('sfx $asset failed: $e');
    }
  }

  /// Decodes the effects ahead of time so the first tick/boom isn't late.
  Future<void> preload() async {
    await init();
    for (final a in const [
      'audio/sfx/tick.wav', 'audio/sfx/wrong.wav', 'audio/sfx/beep800.wav',
      'audio/sfx/beep1200.wav', 'audio/sfx/boom.wav', 'audio/sfx/victory.wav',
      'audio/start.mp3', 'audio/correct.mp3', 'audio/gameover.mp3',
    ]) {
      try {
        final p = _sfx.putIfAbsent(a, () {
          final p = AudioPlayer();
          p.setPlayerMode(PlayerMode.lowLatency);
          p.setReleaseMode(ReleaseMode.stop);
          return p;
        });
        await p.setSource(AssetSource(a));
      } catch (_) {}
    }
  }
}
