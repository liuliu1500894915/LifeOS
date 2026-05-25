import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_os/app.dart';
import 'package:life_os/core/widgets/status_capsule.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const ProviderScope(
        child: LifeOSApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpRouteTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('app smoke tests', () {
    testWidgets('bottom navigation switches across all five modules', (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester);

      expect(find.text('Life OS'), findsOneWidget);

      await tester.tap(find.text('财务'));
      await pumpRouteTransition(tester);
      expect(find.text('财务中心'), findsOneWidget);

      await tester.tap(find.text('分析'));
      await pumpRouteTransition(tester);
      expect(find.text('数据中枢'), findsOneWidget);

      await tester.tap(find.text('日常'));
      await pumpRouteTransition(tester);
      expect(find.text('行动中心'), findsOneWidget);

      await tester.tap(find.text('我的'));
      await pumpRouteTransition(tester);
      expect(find.text('个人中心'), findsOneWidget);

      await tester.tap(find.text('主页'));
      await pumpRouteTransition(tester);
      expect(find.text('Life OS'), findsOneWidget);
    });

    testWidgets('key routed surfaces open from their module entry points', (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester);

      await tester.tap(find.byType(StatusCapsule).first);
      await pumpRouteTransition(tester);
      expect(find.text('体征仪表盘'), findsOneWidget);
      await tester.pageBack();
      await pumpRouteTransition(tester);

      await tester.tap(find.text('财务'));
      await pumpRouteTransition(tester);
      await tester.tap(find.text('今日花费'));
      await pumpRouteTransition(tester);
      expect(find.text('今日花费明细'), findsOneWidget);
      await tester.pageBack();
      await pumpRouteTransition(tester);

      await tester.tap(find.text('日常'));
      await pumpRouteTransition(tester);
      await tester.tap(find.text('A. 重要·紧急'));
      await pumpRouteTransition(tester);
      expect(find.text('A. 重要·紧急'), findsWidgets);
      await tester.pageBack();
      await pumpRouteTransition(tester);

      await tester.tap(find.text('我的'));
      await pumpRouteTransition(tester);
      await tester.tap(find.text('证件资产库'));
      await pumpRouteTransition(tester);
      expect(find.text('安全验证'), findsOneWidget);
      await tester.tap(find.text('验证进入'));
      await pumpRouteTransition(tester);
      expect(find.text('护照'), findsOneWidget);
    });
  });
}
