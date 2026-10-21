import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'fuckxter_api.dart';

class MediaImage extends ImageProvider<MediaImage> {
  const MediaImage(this.uri, {this.cookie});

  final Uri uri;
  final String? cookie;

  @override
  Future<MediaImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(MediaImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    if (!FuckXterApi.isMediaUri(uri)) {
      throw const ApiException('图片地址无效。', 0);
    }
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['Accept'] = 'image/webp';
      if (!kIsWeb && cookie != null) request.headers['Cookie'] = cookie!;
      final bytes = await (() async {
        final response = await client.send(request);
        if (response.statusCode != 200 ||
            response.headers['content-type']?.split(';').first !=
                'image/webp') {
          throw const ApiException('图片加载失败，请重试。', 0);
        }
        const limit = 30 * 1024 * 1024;
        if ((response.contentLength ?? 0) > limit) {
          throw const ApiException('图片过大。', 413);
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > limit) {
            throw const ApiException('图片过大。', 413);
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      })().timeout(const Duration(seconds: 30));
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } finally {
      client.close();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MediaImage && other.uri == uri && other.cookie == cookie;

  @override
  int get hashCode => Object.hash(uri, cookie);
}
