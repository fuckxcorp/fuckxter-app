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
  testWidgets(
    'WebP images reuse one client without mixing credentials or colors',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = await File('test/fixtures/rgb.webp').readAsBytes();
        var clients = 0;
        final cookies = <String?>[];
        final client = _Client((request) async {
          expect(request.followRedirects, isFalse);
          expect(request.headers['accept'], 'image/webp');
          cookies.add(request.headers['cookie']);
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/webp'},
          );
        });
        addTearDown(client.close);
        await http.runWithClient(
          () async {
            for (final cookie in ['fk_session=first', 'fk_session=second']) {
              final provider = MediaImage(
                FuckXterApi.displayUri('/media/colors', 640),
                cookie: cookie,
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
            }
            expect(clients, 1);
            expect(client.closes, 0);
            expect(cookies, ['fk_session=first', 'fk_session=second']);
            await Future.wait(client.aborts);
          },
          () {
            clients++;
            return client;
          },
        );
      });
    },
  );
}

class _Client extends MockClient {
  _Client(Future<http.Response> Function(http.Request) handler)
    : super(handler);

  int closes = 0;
  final aborts = <Future<void>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    aborts.add((request as http.Abortable).abortTrigger!);
    return super.send(request);
  }

  @override
  void close() {
    closes++;
    super.close();
  }
}
