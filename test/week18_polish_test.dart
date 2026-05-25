import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:life_os/features/daily/presentation/pages/quadrant_todo_page.dart';
import 'package:life_os/features/daily/presentation/providers/daily_providers.dart';
import 'package:life_os/features/home/presentation/widgets/today_snapshot.dart';

void main() {
  group('week 18 polish', () {
    testWidgets('today snapshot stays usable on wide layouts', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(24),
                child: TodaySnapshot(),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('今日动态'), findsOneWidget);
      expect(find.text('待办'), findsOneWidget);
      expect(find.text('花费'), findsOneWidget);
      expect(find.text('喝水'), findsOneWidget);
      expect(find.text('运动'), findsOneWidget);
      expect(find.text('睡眠'), findsOneWidget);
      expect(find.text('消耗'), findsOneWidget);
    });

    testWidgets('quadrant route ignores invalid extra payloads', (tester) async {
      final router = GoRouter(
        initialLocation: '/daily/quadrant-todo',
        routes: [
          GoRoute(
            path: '/daily/quadrant-todo',
            builder: (context, state) => QuadrantTodoPage(
              initialQuadrant: state.extra is QuadrantType ? state.extra as QuadrantType : null,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('四象限工作台'), findsOneWidget);

      router.go('/daily/quadrant-todo', extra: 'bad-extra');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('四象限工作台'), findsOneWidget);
    });
  });
}
