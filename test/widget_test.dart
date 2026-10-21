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
  testWidgets('profile data and posts start loading together', (tester) async {
    final profile = Completer<http.Response>();
    final posts = Completer<http.Response>();
    final paths = <String>[];
    final api = FuckXterApi(
      client: MockClient((request) {
        paths.add(request.url.path);
        return request.url.path.endsWith('/posts')
            ? posts.future
            : profile.future;
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          session: AppSession(api: api)..ready = true,
          handle: 'tester',
        ),
      ),
    );
    await tester.pump();
    expect(paths, containsAll(['/users/tester', '/users/tester/posts']));
    profile.complete(http.Response('{"name":"Tester","handle":"tester"}', 200));
    posts.complete(http.Response('{"posts":[]}', 200));
    await tester.pumpAndSettle();
    expect(find.text('还没有帖子'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post details and comments start loading together', (
    tester,
  ) async {
    final details = Completer<http.Response>();
    final comments = Completer<http.Response>();
    final post = _post('parallel');
    final paths = <String>[];
    final api = FuckXterApi(
      client: MockClient((request) {
        paths.add(request.url.path);
        return request.url.path.endsWith('/comments')
            ? comments.future
            : details.future;
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PostScreen(
          session: AppSession(api: api)..ready = true,
          post: Post.fromJson(post),
        ),
      ),
    );
    await tester.pump();
    expect(
      paths,
      containsAll(['/posts/tester/parallel', '/posts/parallel/comments']),
    );
    details.complete(http.Response(jsonEncode(post), 200));
    comments.complete(http.Response('{"comments":[]}', 200));
    await tester.pumpAndSettle();
    expect(find.text('parallel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large history builds visible entries on demand', (tester) async {
    final api = FuckXterApi(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)..ready = true;
    session.history = List.generate(
      200,
      (index) => HistoryItem(
        handle: 'tester',
        slug: '$index',
        name: 'Entry $index',
        text: 'Text $index',
        at: '2026-10-21T00:00:00Z',
      ),
    );
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(session: session)));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(find.text('Entry 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Entry 199'),
      600,
      maxScrolls: 40,
    );
    expect(find.text('Entry 199'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'switches feeds without showing stale posts and reuses cached results',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final latest = Completer<http.Response>();
      final calls = <String>[];
      final api = FuckXterApi(
        client: MockClient((request) async {
          final tab = request.url.queryParameters['tab'] ?? '';
          calls.add(tab);
          if (tab == 'latest') return latest.future;
          return http.Response(
            jsonEncode({
              'posts': [_post('recommended')],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final session = AppSession(api: api)..ready = true;
      await tester.pumpWidget(FuckXterApp(session: session));
      await tester.pumpAndSettle();
      expect(find.text('recommended'), findsOneWidget);
      await tester.tap(find.text('实时'));
      await tester.pumpAndSettle();
      expect(find.text('recommended'), findsNothing);
      await tester.tap(find.text('推荐'));
      await tester.pumpAndSettle();
      expect(find.text('recommended'), findsOneWidget);
      expect(calls.where((tab) => tab == 'foryou'), hasLength(1));
      latest.complete(
        http.Response(
          jsonEncode({
            'posts': [_post('old response')],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('old response'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restores the scroll position when returning to a timeline', (
    tester,
  ) async {
    final api = FuckXterApi(
      client: MockClient((request) async {
        final tab = request.url.queryParameters['tab'];
        return http.Response(
          jsonEncode({'posts': List.generate(20, (i) => _post('$tab $i'))}),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      FuckXterApp(session: AppSession(api: api)..ready = true),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = scroll.offset;
    expect(before, greaterThan(0));
    await tester.tap(find.text('实时'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    await tester.tap(find.text('推荐'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(before, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile navigation opens search and protects account actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FuckXterApi(
      client: MockClient((request) async => http.Response('{"posts":[]}', 200)),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      FuckXterApp(session: AppSession(api: api)..ready = true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('搜索'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('通知'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compose shortcut focuses the editor and shows the character count',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FuckXterApi(
        client: MockClient(
          (request) async => http.Response('{"posts":[]}', 200),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        FuckXterApp(session: AppSession(api: api)..ready = true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('撰写帖子'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), '你好');
      await tester.pumpAndSettle();
      expect(find.text('2/1000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'media grid fits narrow cards and opens the selected gallery image',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FuckXterApi(
        client: MockClient((request) async => http.Response('{}', 200)),
      );
      addTearDown(api.close);
      final json = _post('Photos')
        ..['media'] = List.generate(
          6,
          (i) => {'url': 'https://invalid.example/$i', 'alt': 'Photo $i'},
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(
              post: Post.fromJson(json),
              session: AppSession(api: api)..ready = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('+2'));
      await tester.pumpAndSettle();
      expect(find.text('4 / 6'), findsOneWidget);
      await tester.tap(find.byTooltip('下一张'));
      await tester.pumpAndSettle();
      expect(find.text('5 / 6'), findsOneWidget);
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

Map<String, dynamic> _post(String text) => {
  'id': text,
  'slug': text,
  'author': {'name': 'Tester', 'handle': 'tester'},
  'text': text,
  'createdAt': '2026-10-21T00:00:00Z',
};
