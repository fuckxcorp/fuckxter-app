import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fuckxter_app/services/fuckxter_api.dart';
import 'package:fuckxter_app/services/media_image.dart';

void main() {
  test(
    'invalid JSON response shapes fail instead of becoming empty results',
    () async {
      final api = FuckXterApi(
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      addTearDown(api.close);
      await expectLater(
        api.timeline(tab: 'latest'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('media URLs cannot send session credentials to another origin', () {
    for (final path in [
      'https://evil.example/media/photo',
      '//evil.example/media/photo',
      'http://api.fuckxter.site/media/photo',
      'https://api.fuckxter.site:444/media/photo',
      'https://user@api.fuckxter.site/media/photo',
      '/auth/me',
      'file:///media/photo',
    ]) {
      expect(() => FuckXterApi.media(path), throwsA(isA<ApiException>()));
    }
    final uri = FuckXterApi.displayUri('/avatars/alice?v=updated', 128);
    expect(uri.origin, FuckXterApi.origin);
    expect(uri.queryParameters, {
      'v': 'updated',
      'format': 'webp',
      'width': '128',
    });
  });

  test('private image cache keys include the session and requested size', () {
    final uri = FuckXterApi.displayUri('/media/photo', 640);
    expect(MediaImage(uri, cookie: 'a'), MediaImage(uri, cookie: 'a'));
    expect(MediaImage(uri, cookie: 'a'), isNot(MediaImage(uri, cookie: 'b')));
    expect(MediaImage(uri), isNot(MediaImage(uri, cookie: 'a')));
    expect(
      MediaImage(uri),
      isNot(MediaImage(FuckXterApi.displayUri('/media/photo', 1280))),
    );
  });

  test('authenticated API requests never follow redirects', () async {
    final api = FuckXterApi(
      client: MockClient((request) async {
        expect(request.followRedirects, isFalse);
        expect(request.headers['cookie'], 'fk_session=fixture');
        return http.Response(
          '',
          302,
          headers: {'location': 'https://evil.example'},
        );
      }),
    )..cookie = 'fixture';
    addTearDown(api.close);
    await expectLater(api.me(), throwsA(isA<ApiException>()));
  });

  test('a late response cannot restore a logged out session', () async {
    final result = Completer<http.Response>();
    final api = FuckXterApi(client: MockClient((_) => result.future))
      ..cookie = 'old';
    addTearDown(api.close);
    final request = api.me();
    api.cookie = null;
    result.complete(
      http.Response(
        jsonEncode({'account': null}),
        200,
        headers: {'set-cookie': 'fk_session=rotated; HttpOnly; Secure'},
      ),
    );
    await request;
    expect(api.cookie, isNull);
  });

  test('unrelated cookie names cannot overwrite the session', () async {
    final api = FuckXterApi(
      client: MockClient(
        (_) async => http.Response(
          '{"account":null}',
          200,
          headers: {'set-cookie': 'not_fk_session=bad; Secure'},
        ),
      ),
    )..cookie = 'fixture';
    addTearDown(api.close);
    await api.me();
    expect(api.cookie, 'fixture');
  });
}
