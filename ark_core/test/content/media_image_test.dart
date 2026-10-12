import 'dart:io';

import 'package:ark_core/content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// 1×1 transparent PNG.
const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0xE2, 0x26, 0x05, 0x9B, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
];

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('ark_img'));
  tearDown(() => tmp.delete(recursive: true));

  testWidgets('downloaded picture is shown from the cache; missing → placeholder',
      (tester) async {
    await ArkMedia.instance.configure(
      source: const MediaSource.firebase(bucket: 'b.appspot.com'),
      bundledAssets: const {},
      cacheDir: tmp,
      client: MockClient((req) async => req.url.toString().contains('missing')
          ? http.Response('no', 404)
          : http.Response.bytes(_png, 200)),
    );
    // Real file IO (cache) does not advance under the test's fake clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Column(children: [
          ArkMediaImage('images/vocab/211.webp', width: 40, height: 40),
          ArkMediaImage('images/vocab/missing.webp', placeholder: Text('なし')),
        ]),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();
    });
    expect(find.byType(Image), findsOneWidget);
    expect((tester.widget<Image>(find.byType(Image)).image), isA<FileImage>());
    expect(find.text('なし'), findsOneWidget);
    expect(ArkMediaImage.providerFor('images/vocab/211.webp'), isA<FileImage>());
    expect(ArkMediaImage.providerFor('images/vocab/missing.webp'), isNull);
  });
}
