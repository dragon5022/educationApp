import 'dart:io';

import 'package:flutter/material.dart';

import 'ark_media.dart';

/// Shows a picture referenced by question data (`images/vocab/001.webp`):
/// from the asset bundle when bundled, else from the media cache,
/// downloading it first when needed. Shows [placeholder] (or nothing)
/// while missing.
class ArkMediaImage extends StatefulWidget {
  const ArkMediaImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.filterQuality = FilterQuality.medium,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final FilterQuality filterQuality;

  /// `ImageProvider` for [path] if it is available right now (for
  /// `precacheImage` and the like), else null.
  static ImageProvider? providerFor(String path) {
    final ref = ArkMedia.instance.resolveSync(path);
    return switch (ref?.kind) {
      MediaKind.asset => AssetImage(ref!.assetPath!),
      MediaKind.file => FileImage(ref!.file!),
      MediaKind.url => NetworkImage(ref!.uri!.toString()),
      _ => null,
    };
  }

  @override
  State<ArkMediaImage> createState() => _ArkMediaImageState();
}

class _ArkMediaImageState extends State<ArkMediaImage> {
  MediaRef? _ref;

  @override
  void initState() {
    super.initState();
    ArkMedia.instance.revision.addListener(_refresh);
    _resolve();
  }

  @override
  void didUpdateWidget(ArkMediaImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _resolve();
  }

  @override
  void dispose() {
    ArkMedia.instance.revision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (_ref == null || !_ref!.exists) _resolve();
  }

  Future<void> _resolve() async {
    final ref = await ArkMedia.instance.resolve(widget.path);
    if (mounted) setState(() => _ref = ref);
  }

  @override
  Widget build(BuildContext context) {
    final ref = _ref;
    final empty = widget.placeholder ??
        SizedBox(width: widget.width, height: widget.height);
    return switch (ref?.kind) {
      MediaKind.asset => Image.asset(
          ref!.assetPath!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          gaplessPlayback: true,
        ),
      MediaKind.file => Image.file(
          File(ref!.file!.path),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          gaplessPlayback: true,
        ),
      MediaKind.url => Image.network(
          ref!.uri!.toString(),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => empty,
        ),
      _ => empty,
    };
  }
}
