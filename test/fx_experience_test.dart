import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuckxter_app/main.dart';
import 'package:fuckxter_app/models/models.dart';
import 'package:fuckxter_app/screens/flows.dart';
import 'package:fuckxter_app/services/fuckxter_api.dart';
import 'package:fuckxter_app/session.dart';
import 'package:fuckxter_app/widgets/bits.dart';
import 'package:fuckxter_app/widgets/fx_controls.dart';
import 'package:fuckxter_app/widgets/post_card.dart';

Map<String, dynamic> post(String id) => {
  'id': id,
  'slug': id,
  'text': id,
  'author': {'name': 'Alice', 'handle': 'alice'},
  'createdAt': '2026-10-22T00:00:00Z',
};
void phone(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'cold start restores the remembered feed before requesting posts',
    (tester) async {
      SharedPreferences.setMockInitialValues({'fk_feed_tab': 'latest'});
      FlutterSecureStorage.setMockInitialValues({});
      final tabs = <String?>[];
      final api = FuckXterApi(
        client: MockClient((request) async {
          tabs.add(request.url.queryParameters['tab']);
          return http.Response('{"posts":[]}', 200);
        }),
      );
      addTearDown(api.close);
      final session = AppSession(api: api);
      await tester.pumpWidget(FuckXterApp(session: session));
      await session.bootstrap();
      await tester.pumpAndSettle();
      expect(tabs, ['latest']);
      expect(session.feedTab, 'latest');
    },
  );

  testWidgets('unfolding and rotation preserve draft, feed and scroll state', (
    tester,
  ) async {
    phone(tester, const Size(466, 678));
    final api = FuckXterApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'posts': List.generate(
              20,
              (i) => post('${request.url.queryParameters['tab']} $i'),
            ),
          }),
          200,
        ),
      ),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)..ready = true;
    await tester.pumpWidget(FuckXterApp(session: session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '未发出的草稿');
    final draft = tester.widget<TextField>(find.byType(TextField)).controller!;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('实时'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = controller.offset;
    tester.view.physicalSize = const Size(890, 626);
    await tester.pumpAndSettle();
    expect(find.byType(FxSidebar), findsOneWidget);
    expect(controller.offset, closeTo(before, 1));
    expect(session.feedTab, 'latest');
    expect(draft.text, '未发出的草稿');
    tester.view.physicalSize = const Size(626, 890);
    await tester.pumpAndSettle();
    expect(find.byType(FxNavigationBar), findsOneWidget);
    expect(controller.offset, closeTo(before, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('crossing root sections never reads notifications in passing', (
    tester,
  ) async {
    phone(tester, const Size(390, 844));
    var read = 0;
    var noticeLoads = 0;
    final api = FuckXterApi(
      client: MockClient((request) async {
        if (request.url.path == '/notice') {
          if (request.method == 'POST') {
            read++;
          } else {
            noticeLoads++;
          }
        }
        return http.Response('{"posts":[],"threads":[],"notices":[]}', 200);
      }),
    );
    addTearDown(api.close);
    final session = AppSession(api: api)
      ..ready = true
      ..account = Account.fromJson({
        'profile': {'name': 'Alice', 'handle': 'alice'},
      });
    await tester.pumpWidget(FuckXterApp(session: session));
    await tester.pumpAndSettle();
    expect(find.byTooltip('搜索'), findsNothing);
    expect(find.byKey(const ValueKey('fx-tab-收藏')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fx-tab-我的')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedScreen), findsOneWidget);
    expect(read, 0);
    expect(noticeLoads, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fx-tab-通知')));
    await tester.pumpAndSettle();
    expect(noticeLoads, 1);
    expect(read, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact previews truncate long messages to one line', (
    tester,
  ) async {
    phone(tester, const Size(320, 720));
    final body = List.filled(100, '这是一条很长的私信\n').join();
    final api = FuckXterApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'threads': [
              {
                'id': '1',
                'other': {'name': 'Alice', 'handle': 'alice'},
                'lastMessage': {'body': body},
              },
            ],
          }),
          200,
          headers: {"content-type": "application/json; charset=utf-8"},
        ),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(session: AppSession(api: api)..ready = true),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((text) => text.data?.startsWith('这是一条') ?? false);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.data, isNot(contains('\n')));
    final render = tester.renderObject<RenderParagraph>(find.text(text.data!));
    expect(render.didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'feed fades before opening a thread and is interactive on return',
    (tester) async {
      phone(tester, const Size(390, 844));
      final api = FuckXterApi(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/comments')
                  ? {'comments': []}
                  : request.url.path == '/timeline'
                  ? {
                      'posts': [post('Hello Fx')],
                    }
                  : post('Hello Fx'),
            ),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        FuckXterApp(session: AppSession(api: api)..ready = true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello Fx'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(PostScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(PostScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello Fx'));
      await tester.pumpAndSettle();
      expect(find.byType(PostScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery morphs continuously with the swipe and preserves ratios',
    (tester) async {
      phone(tester, const Size(390, 844));
      final api = FuckXterApi(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      addTearDown(api.close);
      const media = [
        PostMedia(id: 'a', url: 'https://invalid.example/a', alt: ''),
        PostMedia(id: 'b', url: 'https://invalid.example/b', alt: ''),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaGallery(
            media: media,
            api: api,
            initial: 0,
            ratios: const {
              'https://invalid.example/a': 2,
              'https://invalid.example/b': .75,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      double height() =>
          tester.getSize(find.byKey(const ValueKey('gallery-viewport'))).height;
      final start = height();
      expect(start, closeTo(195, .1));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pump();
      expect(height(), greaterThan(start));
      expect(height(), lessThan(520));
      await gesture.moveBy(const Offset(-150, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(height(), closeTo(520, .1));
      await tester.tap(find.byTooltip('上一张'));
      await tester.pumpAndSettle();
      expect(height(), closeTo(start, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first image resolves its ratio and releases focus blur after settling',
    (tester) async {
      phone(tester, const Size(390, 844));
      final bytes = (await tester.runAsync(
        () => File('test/fixtures/rgb.webp').readAsBytes(),
      ))!;
      final client = MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'image/webp'},
        ),
      );
      await http.runWithClient(() async {
        Size? size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NetImage(
                url: '/media/focus',
                fit: BoxFit.contain,
                width: 300,
                focus: true,
                onDimensions: (value) => size = value,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        await tester.pump();
        expect(size, const Size(3, 1));
        expect(find.byType(ImageFiltered), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ImageFiltered), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
