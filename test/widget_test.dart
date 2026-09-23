import 'package:flutter_test/flutter_test.dart';
import 'package:fuckxter_app/main.dart';

void main() {
  testWidgets('renders the FuckXter shell', (tester) async {
    await tester.pumpWidget(const FuckXterApp());
    expect(find.text('FuckXter'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('有什么新鲜事？'), findsOneWidget);
  });
}
