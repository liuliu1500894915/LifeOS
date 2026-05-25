import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/features/profile/presentation/providers/profile_providers.dart';
import 'package:life_os/features/profile/presentation/providers/security_providers.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, ProviderContainer container) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: createAppRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpRouteTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('module smoke flows', () {
    testWidgets('profile vault and relationship actions mutate provider state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpApp(tester, container);

      await tester.tap(find.text('我的'));
      await pumpRouteTransition(tester);

      await tester.tap(find.text('证件资产库'));
      await pumpRouteTransition(tester);
      await tester.tap(find.text('验证进入'));
      await pumpRouteTransition(tester);
      expect(container.read(securityGateProvider), isTrue);
      expect(find.text('护照'), findsOneWidget);
      await tester.pageBack();
      await pumpRouteTransition(tester);

      final beforeWarmth = container
          .read(relationshipProvider)
          .firstWhere((item) => item.id == 'r1')
          .warmthScore;
      await tester.tap(find.text('核心人际关系互动温度计'));
      await pumpRouteTransition(tester);
      expect(find.text('人际关系网'), findsOneWidget);
      await tester.tap(find.text('记录互动').first);
      await pumpRouteTransition(tester);

      final afterWarmth = container
          .read(relationshipProvider)
          .firstWhere((item) => item.id == 'r1')
          .warmthScore;
      expect(afterWarmth, greaterThan(beforeWarmth));
    });
  });
}
