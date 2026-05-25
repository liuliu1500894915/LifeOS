import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/core/widgets/number_keyboard.dart';
import 'package:life_os/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:life_os/features/daily/presentation/providers/daily_providers.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';
import 'package:life_os/features/home/presentation/providers/home_providers.dart';
import 'package:life_os/features/home/presentation/providers/room_providers.dart';
import 'package:life_os/features/home/presentation/widgets/drink_drawer.dart';
import 'package:life_os/features/profile/presentation/providers/profile_providers.dart';

ProviderContainer _containerWithDb() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  return ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
}

void main() {
  group('cross-module consistency', () {
    test('memorial additions enqueue a daily todo through the event bridge', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final subscription = container.listen<void>(
        memorialTodoBridgeProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

      final beforeCount = container.read(quadrantTodoProvider).length;
      final memorial = MemorialItem(
        id: 'm-test',
        name: '测试纪念日',
        date: DateTime(2026, 6, 1),
        advanceDays: 3,
      );

      container.read(memorialNotifierProvider.notifier).addMemorial(memorial);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final todos = container.read(quadrantTodoProvider);
      expect(todos.length, beforeCount + 1);
      expect(todos.last.title, '准备：测试纪念日');
      expect(todos.last.quadrant, QuadrantType.B);
      expect(todos.last.targetDate, memorial.date.subtract(const Duration(days: 3)));
    });

    testWidgets('beverage records update home logs, finance ledger, and analytics totals', (tester) async {
      final container = _containerWithDb();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DrinkDrawer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tapKeyboardKey(String key) async {
        final keyFinder = find.descendant(
          of: find.byType(NumberKeyboard),
          matching: find.text(key),
        );
        expect(keyFinder, findsOneWidget);
        await tester.tap(keyFinder);
        await tester.pump();
      }

      await tester.tap(find.text('饮料 🥤'));
      await tester.pumpAndSettle();

      for (final key in ['3', '5', '0']) {
        await tapKeyboardKey(key);
      }

      await tester.tap(find.text('卡路里'));
      await tester.pump();
      for (final key in ['1', '5', '0']) {
        await tapKeyboardKey(key);
      }

      await tester.tap(find.text('金额'));
      await tester.pump();
      for (final key in ['1', '2', '.', '5']) {
        await tapKeyboardKey(key);
      }

      await tester.tap(
        find.descendant(
          of: find.byType(NumberKeyboard),
          matching: find.byIcon(Icons.check),
        ),
      );
      await tester.pumpAndSettle();

      // Wait for the async Drift write triggered by drink_drawer's _save
      await container.read(transactionProvider.future);
      await container.read(accountProvider.future);
      // Allow Riverpod listeners to propagate
      await tester.pump();

      final logs = container.read(actionLogNotifierProvider);
      final lastLog = logs.last;
      expect(lastLog.actionType, ActionType.drink);
      expect(lastLog.subCategory, 'beverage');
      expect(lastLog.valueNumeric, 350);
      expect(lastLog.associatedCost, 12.5);
      expect(lastLog.remark, '150kcal');

      final transactions = container.read(todayTransactionsProvider);
      final lastTransaction = transactions.last;
      expect(lastTransaction.categoryId, 'drink');
      expect(categoryForId(lastTransaction.categoryId).name, '饮品');
      expect(lastTransaction.amount, 12.5);
      expect(lastTransaction.remark, '含糖饮料');

      final finance = container.read(financeAnalyticsProvider);
      expect(finance.expense, closeTo(12.5, 0.001));
      expect(finance.categoryExpenses['饮品'], closeTo(12.5, 0.001));
    });

    test('weekly report stays aligned with finance and daily summaries', () async {
      final container = _containerWithDb();
      addTearDown(container.dispose);

      // Wait for Drift-backed providers to seed
      await container.read(accountProvider.future);

      container.read(todoNotifierProvider.notifier).toggleComplete('t1');
      container.read(habitNotifierProvider.notifier).checkHabit('h2');
      container.read(actionLogNotifierProvider.notifier).addAction(
            PetActionLog(
              logId: 'drink-extra',
              actionType: ActionType.drink,
              valueNumeric: 250,
              subCategory: 'water',
              createdAt: DateTime.now(),
            ),
          );

      // Add transaction via the Drift-backed notifier (async)
      final accounts = await container.read(accountProvider.future);
      final wechatAccount = accounts.firstWhere((a) => a.accountName == '微信支付');
      await container.read(transactionProvider.notifier).addTransaction(
            flowType: 'EXPENSE',
            amount: 30,
            categoryId: 'drink',
            accountId: wechatAccount.accountId,
            loggedAt: DateTime.now(),
          );

      final daily = container.read(dailyAnalyticsProvider);
      final report = container.read(weeklyReportProvider);
      final insight = container.read(insightCardProvider);

      expect(daily.waterMl, 1100);
      expect(daily.habitChecked, 3);
      expect(report[0], contains('本周总支出 ¥30'));
      expect(report[1], contains('Todo 完成率 22.2%'));
      expect(report[1], contains('习惯完成 3/4'));
      expect(report[2], contains('重点洞察：'));
      expect(insight.coefficient, lessThan(0));
    });

    test('room projections stay ordered after move, clamp, and bring-to-front updates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(roomFurnitureNotifierProvider.notifier);
      notifier.move('f1', const Offset(10, -20));
      notifier.setScale('f1', 5);
      notifier.bringToFront('f1');

      final raw = container.read(roomFurnitureNotifierProvider);
      final moved = raw.firstWhere((item) => item.placementId == 'f1');
      expect(moved.posX, 230);
      expect(moved.posY, 160);
      expect(moved.scale, 1.8);

      final projected = container.read(roomFurnitureProvider);
      final zIndexes = projected.map((item) => item.zIndex).toList();
      final sorted = [...zIndexes]..sort();
      expect(zIndexes, orderedEquals(sorted));
      expect(projected.last.placementId, 'f1');
    });
  });
}
