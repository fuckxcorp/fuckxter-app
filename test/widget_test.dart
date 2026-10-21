import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fuckxter_app/models/models.dart';
import 'package:fuckxter_app/widgets/post_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fuckxter_app/main.dart';
import 'package:fuckxter_app/services/fuckxter_api.dart';
import 'package:fuckxter_app/session.dart';
import 'package:fuckxter_app/screens/flows.dart';

void main() {
  testWidgets(
    'renders the shell on a narrow screen and retries an empty feed',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final api = FuckXterApi(
        client: MockClient((request) async {
          calls++;
          return http.Response('{"posts":[],"nextCursor":null}', 200);
        }),
      );
      addTearDown(api.close);
      final session = AppSession(api: api)..ready = true;
      await tester.pumpWidget(FuckXterApp(session: session));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('FuckXter'), findsWidgets);
      expect(find.text('推荐'), findsOneWidget);
      expect(find.text('有什么新鲜事？'), findsOneWidget);
      expect(find.text('还没有帖子，发出第一条动态吧'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search ignores older responses and clears empty queries', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final api = FuckXterApi(
      client: MockClient((request) async {
        if (request.url.queryParameters['q'] == 'old') return old.future;
        return http.Response(
          '{"posts":[],"users":[{"name":"Latest result","handle":"latest"}]}',
          200,
        );
      }),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)..ready = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(session: session, query: 'old'),
      ),
    );
    await tester.enterText(find.byType(TextField), 'new');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Latest result'), findsOneWidget);
    old.complete(http.Response('{"posts":[],"users":[]}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Latest result'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Latest result'), findsNothing);
  });
  testWidgets('reposts open their own reply thread instead of the source', (
    tester,
  ) async {
    final json = <String, dynamic>{
      'id': 'wrapper',
      'slug': 'thread',
      'author': {'name': 'Reposter', 'handle': 'reposter'},
      'text': '',
      'repostKind': 'repost',
      'stats': {'likes': 7},
      'source': {
        'id': 'source',
        'slug': 'original',
        'text': 'Original text',
        'author': {'name': 'Original', 'handle': 'original'},
        'stats': {'likes': 99},
      },
    };
    final paths = <String>[];
    final api = FuckXterApi(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          request.url.path.endsWith('/comments')
              ? '{"comments":[]}'
              : jsonEncode(json),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)..ready = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: Post.fromJson(json), session: session),
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.text('99'), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.chat_bubble));
    await tester.pumpAndSettle();
    expect(paths, contains('/posts/reposter/thread'));
    expect(paths, contains('/posts/wrapper/comments'));
    expect(paths, isNot(contains('/posts/source/comments')));
    expect(tester.takeException(), isNull);
  });
}
