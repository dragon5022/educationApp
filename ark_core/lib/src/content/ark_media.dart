import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'sheet_codec.dart';

/// Where media that is not bundled in the app (new voice clips, pictures)
/// is downloaded from.
///
/// `content_source.json`:
/// ```json
/// "firebaseBucket": "ark-busters.firebasestorage.app", "mediaFolder": "media"
/// ```
/// or any plain file host: `"mediaBaseUrl": "https://example.com/media"`.
///
/// Files keep the same relative path the question data uses, e.g. the
/// sheet says `audio/voice/lis/g5_0_17.mp3` and the file is uploaded to
/// `media/audio/voice/lis/g5_0_17.mp3` in Storage.
class MediaSource {
  const MediaSource.firebase({required this.bucket, this.folder = 'media'})
      : _base = null;

  const MediaSource.url(String baseUrl)
      : _base = baseUrl,
        bucket = null,
        folder = '';

  static MediaSource? fromConfig(Map<String, dynamic> config) {
    final bucket = '${config['firebaseBucket'] ?? ''}'.trim();
    if (bucket.isNotEmpty) {
      final folder = '${config['mediaFolder'] ?? 'media'}'.trim();
      return MediaSource.firebase(bucket: bucket, folder: folder.isEmpty ? 'media' : folder);
    }
    final base = '${config['mediaBaseUrl'] ?? ''}'.trim();
    if (base.isNotEmpty) return MediaSource.url(base);
    return null;
  }

  /// Firebase Storage bucket (`<project>.firebasestorage.app` or
  /// `<project>.appspot.com`), or null for [url].
  final String? bucket;
  final String folder;
  final String? _base;

  /// Public download URL for [relPath].
  Uri urlFor(String relPath) {
    final bucket = this.bucket;
    if (bucket != null) {
      // Firebase Storage: the object path is one URL-encoded segment.
      final object = folder.isEmpty ? relPath : '$folder/$relPath';
      return Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(object)}?alt=media',
      );
    }
    final b = _base ?? '';
    final base = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    return Uri.parse('$base/${relPath.split('/').map(Uri.encodeComponent).join('/')}');
  }
}

enum MediaKind { asset, file, url, missing }

/// Where a media path can be read from.
class MediaRef {
  const MediaRef._(this.kind, {this.assetPath, this.file, this.uri});
  const MediaRef.asset(String path) : this._(MediaKind.asset, assetPath: path);
  const MediaRef.file(File f) : this._(MediaKind.file, file: f);

  /// Web only (no file system): stream straight from the host.
  const MediaRef.url(Uri u) : this._(MediaKind.url, uri: u);
  static const missing = MediaRef._(MediaKind.missing);

  final MediaKind kind;

  /// `assets/…` key for `Image.asset` / `AssetSource` (strip `assets/`).
  final String? assetPath;
  final File? file;
  final Uri? uri;

  bool get exists => kind != MediaKind.missing;
}

/// Resolves media paths used by question packs: bundled asset → local
/// cache → download from [MediaSource]. Downloads are cached in the app's
/// support directory, so content works offline once fetched.
class ArkMedia {
  ArkMedia._();
  static final ArkMedia instance = ArkMedia._();

  MediaSource? _source;
  Set<String>? _bundled;
  Directory? _dir;
  http.Client? _client;
  final Map<String, Future<File?>> _inFlight = {};

  /// Bumps whenever a new file lands in the cache (rebuild images).
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get canDownload => _source != null;

  Future<void> configure({
    MediaSource? source,
    @visibleForTesting Set<String>? bundledAssets,
    @visibleForTesting Directory? cacheDir,
    @visibleForTesting http.Client? client,
  }) async {
    _source = source;
    _bundled = bundledAssets;
    _dir = cacheDir;
    _client = client;
    _inFlight.clear();
  }

  static final _mediaExt = RegExp(
    r'\.(mp3|m4a|wav|ogg|png|jpe?g|webp|gif)$',
    caseSensitive: false,
  );

  /// True for strings that look like a media file path.
  static bool looksLikeMedia(String v) =>
      _mediaExt.hasMatch(v) && !v.startsWith('http') && !v.contains('..');

  static String _norm(String path) =>
      path.startsWith('assets/') ? path.substring('assets/'.length) : path;

  Future<Set<String>> _assets() async {
    if (_bundled != null) return _bundled!;
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      return _bundled = m.listAssets().toSet();
    } catch (e) {
      debugPrint('asset manifest: $e');
      return _bundled = {};
    }
  }

  Future<Directory> _cache() async {
    if (_dir != null) return _dir!;
    final root = await getApplicationSupportDirectory();
    return _dir = await Directory('${root.path}/ark_media').create(recursive: true);
  }

  File _cacheFile(Directory dir, String rel) => File('${dir.path}/$rel');

  /// Where [path] (e.g. `audio/voice/voca/1.mp3`, with or without the
  /// `assets/` prefix) can be read from. With [download], a missing file
  /// is fetched first (may take a moment online; instant offline).
  Future<MediaRef> resolve(String path, {bool download = true}) async {
    final rel = _norm(path);
    if ((await _assets()).contains('assets/$rel')) return MediaRef.asset('assets/$rel');
    if (kIsWeb) return _webRef(rel);
    final f = _cacheFile(await _cache(), rel);
    if (await f.exists() && await f.length() > 0) return MediaRef.file(f);
    if (download) {
      final d = await fetch(rel);
      if (d != null) return MediaRef.file(d);
    }
    return MediaRef.missing;
  }

  /// Synchronous best effort for widgets: bundled → asset; cached → file;
  /// else null (and a download starts if possible).
  MediaRef? resolveSync(String path) {
    final rel = _norm(path);
    final assets = _bundled;
    if (assets != null && assets.contains('assets/$rel')) return MediaRef.asset('assets/$rel');
    if (kIsWeb) return assets == null ? null : _webRef(rel);
    final dir = _dir;
    if (dir != null) {
      final f = _cacheFile(dir, rel);
      if (f.existsSync() && f.lengthSync() > 0) return MediaRef.file(f);
    }
    unawaited(resolve(rel));
    return null;
  }

  /// Downloads [rel] into the cache (no-op if already there). Returns the
  /// file, or null when offline / not configured / not found.
  /// Browsers have no file cache: play / show from the host directly.
  MediaRef _webRef(String rel) {
    final s = _source;
    return s == null ? MediaRef.missing : MediaRef.url(s.urlFor(rel));
  }

  Future<File?> fetch(String rel) {
    rel = _norm(rel);
    if (kIsWeb) return Future.value(null);
    return _inFlight.putIfAbsent(rel, () async {
      try {
        final dir = await _cache();
        final f = _cacheFile(dir, rel);
        if (await f.exists() && await f.length() > 0) return f;
        final source = _source;
        if (source == null) return null;
        final client = _client ?? http.Client();
        try {
          final res = await client
              .get(source.urlFor(rel))
              .timeout(const Duration(seconds: 30));
          if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
            debugPrint('media $rel: HTTP ${res.statusCode}');
            return null;
          }
          await f.parent.create(recursive: true);
          final tmp = File('${f.path}.part');
          await tmp.writeAsBytes(res.bodyBytes, flush: true);
          await tmp.rename(f.path);
          revision.value++;
          return f;
        } finally {
          if (_client == null) client.close();
        }
      } catch (e) {
        debugPrint('media $rel: $e');
        return null;
      } finally {
        _inFlight.remove(rel);
      }
    });
  }

  /// Media paths referenced by a pack's questions (any string value that
  /// looks like a media file).
  static Set<String> mediaPathsOf(Map<String, dynamic> pack) {
    final out = <String>{};
    void walk(dynamic v) {
      if (v is Map) {
        v.values.forEach(walk);
      } else if (v is List) {
        v.forEach(walk);
      } else if (v is String && looksLikeMedia(v)) {
        out.add(_norm(v));
      }
    }
    for (final items in itemArrays(pack).values) {
      items.forEach(walk);
    }
    return out;
  }

  /// Downloads every media file of [pack] that is neither bundled nor
  /// cached. Returns the number of files fetched. Never throws.
  Future<int> prefetchPack(Map<String, dynamic> pack, {int concurrency = 3}) async {
    if (_source == null || kIsWeb) return 0;
    final assets = await _assets();
    final dir = await _cache();
    final todo = [
      for (final rel in mediaPathsOf(pack))
        if (!assets.contains('assets/$rel') && !_cacheFile(dir, rel).existsSync()) rel,
    ];
    var fetched = 0;
    for (var i = 0; i < todo.length; i += concurrency) {
      final results = await Future.wait(todo.skip(i).take(concurrency).map(fetch));
      fetched += results.whereType<File>().length;
    }
    return fetched;
  }

  /// Deletes downloaded files (bundled assets are unaffected).
  Future<void> clearCache() async {
    if (kIsWeb) return;
    final dir = await _cache();
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    revision.value++;
  }
}
