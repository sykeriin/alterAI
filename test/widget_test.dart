// Smoke test: the app boots and renders without throwing.

import 'package:alter/src/app/alter_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('AlterApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TickerMode(enabled: false, child: AlterApp())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(AlterApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
