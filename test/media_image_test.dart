import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fuckxter_app/services/fuckxter_api.dart';
import 'package:fuckxter_app/services/media_image.dart';

void main() {
  testWidgets('WebP transport preserves red, green and blue channels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await File('test/fixtures/rgb.webp').readAsBytes();
      await http.runWithClient(
        () async {
          final provider = MediaImage(
            FuckXterApi.displayUri('/media/colors', 640),
            cookie: 'fk_session=fixture',
          );
          final result = Completer<ImageInfo>();
          final stream = provider.resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (image, _) => result.complete(image),
            onError: (Object error, StackTrace? stack) =>
                result.completeError(error, stack),
          );
          stream.addListener(listener);
          try {
            final info = await result.future;
            final pixels = await info.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            expect(info.image.width, 3);
            expect(info.image.height, 1);
            expect(pixels!.buffer.asUint8List(), [
              255,
              0,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              0,
              255,
              255,
            ]);
            info.dispose();
          } finally {
            stream.removeListener(listener);
            await provider.evict();
          }
        },
        () => MockClient((request) async {
          expect(request.followRedirects, isFalse);
          expect(request.headers['cookie'], 'fk_session=fixture');
          expect(request.headers['accept'], 'image/webp');
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/webp'},
          );
        }),
      );
    });
  });
}
