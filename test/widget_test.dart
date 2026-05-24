import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_os/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LifeOSApp(),
      ),
    );

    expect(find.text('Life OS - 全维人生管理系统'), findsOneWidget);
  });
}
