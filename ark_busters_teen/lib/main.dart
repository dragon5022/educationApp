import 'dart:async';
import 'dart:convert';

import 'package:ark_core/content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'data/stage_pack.dart';
import 'screens/stage/stage_screen.dart';
import 'screens/top_screen.dart';
import 'services/audio_service.dart';
import 'services/teen_store.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Screenshot-test builds only: --dart-define=TEEN_TEST_SLOWMO=8 slows
  // animations (not the game clock) so short effects can be captured.
  const slowmo = int.fromEnvironment('TEEN_TEST_SLOWMO', defaultValue: 1);
  if (slowmo > 1) timeDilation = slowmo.toDouble();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // All question data comes from JSON packs via ArkContent: the bundled
  // copy, or a newer one downloaded from the school's Google Sheet.
  final contentCfg = await _contentConfig();
  // Pictures / audio referenced by new questions: Firebase Storage → cache.
  await ArkMedia.instance.configure(source: MediaSource.fromConfig(contentCfg));
  await ArkContent.instance.configure(
    appId: 'teen',
    bundledPacks: bundledStagePacks,
    source: SheetSource.fromConfig(contentCfg),
    media: ArkMedia.instance,
    appBuild: contentFormatBuild,
    // A downloaded pack is only used if the game can read it.
    validators: {
      for (final id in stagePackIds)
        id: (j) => StagePack.fromJson(jsonDecode(j) as Map<String, dynamic>).levels.isNotEmpty,
    },
  );
  await AudioService.instance.init();
  // Purchases (offline-cached unlock) and optional login / cloud progress.
  await TeenStore.init();
  runApp(const ArkBustersTeenApp());
  // Newer questions from the sheet, if online; used from the next stage.
  unawaited(ArkContent.instance.checkForUpdates().then((_) => ArkContent.instance.prefetchMedia()));
}

class ArkBustersTeenApp extends StatefulWidget {
  const ArkBustersTeenApp({super.key});

  @override
  State<ArkBustersTeenApp> createState() => _ArkBustersTeenAppState();
}

class _ArkBustersTeenAppState extends State<ArkBustersTeenApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      AudioService.instance.pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.instance.resumeBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARK BUSTERS TEEN',
      debugShowCheckedModeBanner: false,
      theme: buildTeenTheme(),
      // Routes mirror the web URLs: / (ark-top) and /<page> (e.g. /e-bunpou).
      onGenerateRoute: (settings) {
        final name = (settings.name ?? '/').replaceAll(RegExp(r'^/|\.html$'), '');
        if (stagePackIds.contains(name)) return stageRoute(name, settings);
        return MaterialPageRoute<void>(settings: settings, builder: (_) => const TopScreen());
      },
      builder: (context, child) {
        final pad = MediaQuery.paddingOf(context);
        return Listener(
          // web: BGM starts on the first click anywhere (autoplay policy).
          onPointerDown: (_) => AudioService.instance.startBgm(),
          child: Stack(
            children: [
              ?child,
              // `.bgm-btn` is position:fixed above every page.
              Positioned(top: pad.top + 10, right: 10, child: const BgmButton()),
            ],
          ),
        );
      },
    );
  }
}

/// `assets/data/content_source.json` (sheet + media settings), or {}.
Future<Map<String, dynamic>> _contentConfig() async {
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/data/content_source.json'));
    return Map<String, dynamic>.from(j as Map);
  } catch (_) {
    return {};
  }
}
