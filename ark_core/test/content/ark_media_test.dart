import 'dart:convert';
import 'dart:io';

import 'package:ark_core/content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tmp;
  late List<Uri> requests;
  final bytes = utf8.encode('ID3 fake mp3');

  MockClient client({bool offline = false}) => MockClient((req) async {
        requests.add(req.url);
        if (offline) throw const SocketException('offline');
        if (req.url.toString().contains('missing')) return http.Response('no', 404);
        return http.Response.bytes(bytes, 200);
      });

  Future<void> setup({bool offline = false, MediaSource? source}) async {
    requests = [];
    await ArkMedia.instance.configure(
      source: source ?? const MediaSource.firebase(bucket: 'ark.appspot.com'),
      bundledAssets: {'assets/audio/voice/voca/1.mp3', 'assets/images/vocab/001.webp'},
      cacheDir: tmp,
      client: client(offline: offline),
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ark_media_test');
  });
  tearDown(() async => tmp.delete(recursive: true));

  test('firebase storage url encodes the object path as one segment', () {
    const s = MediaSource.firebase(bucket: 'ark.appspot.com');
    expect(
      s.urlFor('audio/voice/lis/g5_0_17.mp3').toString(),
      'https://firebasestorage.googleapis.com/v0/b/ark.appspot.com/o/media%2Faudio%2Fvoice%2Flis%2Fg5_0_17.mp3?alt=media',
    );
    expect(
      const MediaSource.url('https://x.example/m/').urlFor('a b/c.png').toString(),
      'https://x.example/m/a%20b/c.png',
    );
    expect(MediaSource.fromConfig({'firebaseBucket': ' b ', 'mediaFolder': ''})!.urlFor('x.mp3').toString(),
        contains('/o/media%2Fx.mp3'));
    expect(MediaSource.fromConfig({}), isNull);
  });

  test('bundled asset wins; nothing downloaded', () async {
    await setup();
    final r = await ArkMedia.instance.resolve('assets/audio/voice/voca/1.mp3');
    expect(r.kind, MediaKind.asset);
    expect(r.assetPath, 'assets/audio/voice/voca/1.mp3');
    expect(requests, isEmpty);
  });

  test('unknown file is downloaded once, cached, then served offline', () async {
    await setup();
    final r = await ArkMedia.instance.resolve('audio/voice/voca/211.mp3');
    expect(r.kind, MediaKind.file);
    expect(await r.file!.readAsBytes(), bytes);
    expect(requests.single.toString(), contains('media%2Faudio%2Fvoice%2Fvoca%2F211.mp3'));
    expect(ArkMedia.instance.revision.value, 1);

    await setup(offline: true); // same cache dir, no network
    final again = await ArkMedia.instance.resolve('audio/voice/voca/211.mp3');
    expect(again.kind, MediaKind.file);
    expect(requests, isEmpty);
  });

  test('missing on the server / offline → missing, no partial files', () async {
    await setup();
    expect((await ArkMedia.instance.resolve('audio/missing.mp3')).exists, isFalse);
    await setup(offline: true);
    expect((await ArkMedia.instance.resolve('audio/voice/voca/212.mp3')).exists, isFalse);
    expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('not configured → bundled only', () async {
    await setup(source: null);
    await ArkMedia.instance.configure(
      bundledAssets: {'assets/a.mp3'},
      cacheDir: tmp,
      client: client(),
    );
    expect(ArkMedia.instance.canDownload, isFalse);
    expect((await ArkMedia.instance.resolve('a.mp3')).kind, MediaKind.asset);
    expect((await ArkMedia.instance.resolve('b.mp3')).exists, isFalse);
  });

  test('prefetchPack fetches only what the device lacks', () async {
    await setup();
    final pack = {
      'items': [
        {'w': 'cafe', 'img': 'images/vocab/001.webp', 'voice': 'audio/voice/voca/1.mp3'},
        {'w': 'new', 'img': 'images/vocab/211.webp', 'voice': 'audio/voice/voca/211.mp3'},
        {'w': 'text only', 'ja': 'not a file.mp3 really'}, // not a path
      ],
    };
    expect(ArkMedia.mediaPathsOf(pack), {
      'images/vocab/001.webp',
      'audio/voice/voca/1.mp3',
      'images/vocab/211.webp',
      'audio/voice/voca/211.mp3',
    });
    final n = await ArkMedia.instance.prefetchPack(pack);
    expect(n, 2);
    expect(requests.length, 2);
    expect(await ArkMedia.instance.prefetchPack(pack), 0); // all cached now
  });

  test('clearCache removes downloads', () async {
    await setup();
    await ArkMedia.instance.resolve('audio/voice/voca/211.mp3');
    await ArkMedia.instance.clearCache();
    expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
