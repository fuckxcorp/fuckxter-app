import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fuckxter_app/main.dart';
import 'package:fuckxter_app/models/models.dart';
import 'package:fuckxter_app/screens/flows.dart';
import 'package:fuckxter_app/screens/preferences_screen.dart';
import 'package:fuckxter_app/services/fuckxter_api.dart';
import 'package:fuckxter_app/session.dart';
import 'package:fuckxter_app/widgets/post_card.dart';

Account account() => Account.fromJson({
  'profile': {'handle': 'alice', 'name': 'Alice'},
});

Post post(String handle) => Post.fromJson({
  'id': 'p1',
  'slug': '1',
  'text': 'fixture',
  'author': {'handle': handle, 'name': handle},
  'stats': <String, dynamic>{},
});

void main() {
  testWidgets('own post has a direct delete action and updates the list', (
    tester,
  ) async {
    final requests = <String>[];
    final api = FuckXterApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)
      ..ready = true
      ..account = account();
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: post('alice'),
            session: session,
            onDeleted: () => deleted = true,
          ),
        ),
      ),
    );
    expect(find.byTooltip('删除'), findsOneWidget);
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(requests, ['DELETE /posts/p1']);
    expect(deleted, isTrue);
    expect(find.text('fixture'), findsNothing);
  });

  testWidgets('other authors have share but no delete action', (tester) async {
    final session = AppSession()
      ..ready = true
      ..account = account();
    addTearDown(session.api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: post('bob'), session: session),
        ),
      ),
    );
    expect(find.byTooltip('删除'), findsNothing);
    expect(find.byTooltip('分享'), findsOneWidget);
    expect(find.byTooltip('复制链接'), findsNothing);
  });

  testWidgets(
    'share invokes the native share channel without copying the link',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return 'dev.test.shared';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final session = AppSession()..ready = true;
      addTearDown(session.api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(post: post('bob'), session: session),
          ),
        ),
      );
      await tester.tap(find.byTooltip('分享'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.arguments.toString(), contains('/post/bob/1'));
      expect(find.text('已复制链接'), findsNothing);
    },
  );

  testWidgets(
    'profile gear exposes the requested destinations only for the owner',
    (tester) async {
      final api = FuckXterApi(
        client: MockClient(
          (_) async => http.Response(
            '{"user":{"handle":"alice","name":"Alice"},"posts":[]}',
            200,
          ),
        ),
      );
      addTearDown(api.close);
      final session = AppSession(api: api)
        ..ready = true
        ..account = account();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(session: session, handle: 'alice'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('个人主页选项'));
      await tester.pumpAndSettle();
      for (final label in ['设置', '编辑个人资料', '私信', '收藏', '历史记录']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.byType(PreferencesScreen), findsOneWidget);
      for (final label in ['存储', '主题', '语言', '账号安全']) {
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets('language changes navigation while preserving user content', (
    tester,
  ) async {
    final api = FuckXterApi(
      client: MockClient((_) async => http.Response('{"posts":[]}', 200)),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)..ready = true;
    await tester.pumpWidget(FuckXterApp(session: session));
    await tester.pumpAndSettle();
    session.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    session.setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  test(
    '2FA proof and storage configuration use authenticated API routes',
    () async {
      final requests = <http.Request>[];
      final api = FuckXterApi(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"secret":"fixture","codes":["a"],"configs":[]}',
            200,
          );
        }),
      );
      addTearDown(api.close);
      await api.beginTwoFactor({'password': 'password', 'code': '123456'});
      await api.recoveryCodes({'password': 'password', 'code': '654321'});
      await api.saveStorage({
        'name': 'S3',
        'endpoint': 'https://s3.example.com',
      });
      await api.deleteStorage('bucket/a');
      expect(jsonDecode(requests[0].body), {
        'password': 'password',
        'code': '123456',
      });
      expect(jsonDecode(requests[1].body)['code'], '654321');
      expect(requests[2].url.path, '/me/storage');
      expect(requests[2].method, 'POST');
      expect(requests[3].url.toString(), endsWith('/me/storage/bucket%2Fa'));
    },
  );
  test('media uploads use the configured default storage', () async {
    String? storage;
    final api = FuckXterApi(
      client: MockClient((request) async {
        if (request.url.path == '/me/storage/options') {
          return http.Response(
            '{"options":[{"id":"custom","isDefault":true}]}',
            200,
          );
        }
        storage = request.headers['X-Storage-Config-Id'];
        return http.Response('{"media":{"id":"m1","url":"/media/m1"}}', 200);
      }),
    );
    addTearDown(api.close);
    await api.uploadMedia(
      bytes: [1, 2, 3],
      name: 'image.png',
      contentType: 'image/png',
    );
    expect(storage, 'custom');
  });
}
