import 'package:flutter_test/flutter_test.dart';
import 'package:fuckxter_app/main.dart';
import 'package:fuckxter_app/session.dart';

void main() {
  testWidgets('renders the FuckXter shell', (tester) async {
    await tester.pumpWidget(FuckXterApp(session: AppSession()));
    expect(find.bySemanticsLabel('FuckXter'), findsWidgets);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('有什么新鲜事？'), findsOneWidget);
  });
}
