import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/daily/presentation/providers/daily_providers.dart';
import '../../../../features/finance/presentation/providers/finance_providers.dart';
import '../../../../features/finance/data/category_seeds.dart';
import '../../../../features/home/presentation/providers/home_providers.dart';
import '../../domain/correlation_engine.dart';

class FinanceAnalyticsSummary {
  final double income;
  final double expense;
  final double balance;
  final Map<String, double> categoryExpenses;

  const FinanceAnalyticsSummary({
    required this.income,
    required this.expense,
    required this.balance,
    required this.categoryExpenses,
  });
}

class DailyAnalyticsSummary {
  final int todoTotal;
  final int todoCompleted;
  final double completionRate;
  final double waterMl;
  final double sleepHours;
  final int habitChecked;
  final int habitTotal;

  const DailyAnalyticsSummary({
    required this.todoTotal,
    required this.todoCompleted,
    required this.completionRate,
    required this.waterMl,
    required this.sleepHours,
    required this.habitChecked,
    required this.habitTotal,
  });
}

final financeAnalyticsProvider = Provider<FinanceAnalyticsSummary>((ref) {
  final txs = ref.watch(todayTransactionsProvider);
  final income = txs.where((t) => t.flowType == 'INCOME').fold<double>(0, (s, t) => s + t.amount);
  final expense = txs.where((t) => t.flowType == 'EXPENSE').fold<double>(0, (s, t) => s + t.amount);
  final byCategory = <String, double>{};
  for (final tx in txs.where((t) => t.flowType == 'EXPENSE')) {
    byCategory.update(categoryForId(tx.categoryId).name, (v) => v + tx.amount, ifAbsent: () => tx.amount);
  }
  return FinanceAnalyticsSummary(
    income: income,
    expense: expense,
    balance: income - expense,
    categoryExpenses: byCategory,
  );
});

final dailyAnalyticsProvider = Provider<DailyAnalyticsSummary>((ref) {
  final todos = ref.watch(quadrantTodoProvider);
  final habits = ref.watch(todayHabitsProvider);
  final homeSummary = ref.watch(todaySummaryProvider);
  final completed = todos.where((t) => t.isCompleted).length;
  final checkedHabits = habits.where((h) => h.todayChecked).length;
  return DailyAnalyticsSummary(
    todoTotal: todos.length,
    todoCompleted: completed,
    completionRate: todos.isEmpty ? 0 : completed / todos.length,
    waterMl: homeSummary.waterMl,
    sleepHours: homeSummary.sleepHours,
    habitChecked: checkedHabits,
    habitTotal: habits.length,
  );
});

final insightCardProvider = Provider<CorrelationResult>((ref) {
  return CorrelationEngine.buildSleepVsImpulse();
});

final weeklyReportProvider = Provider<List<String>>((ref) {
  final finance = ref.watch(financeAnalyticsProvider);
  final daily = ref.watch(dailyAnalyticsProvider);
  final insight = ref.watch(insightCardProvider);
  return [
    '本周总支出 ¥${finance.expense.toStringAsFixed(0)}，结余 ¥${finance.balance.toStringAsFixed(0)}。',
    'Todo 完成率 ${(daily.completionRate * 100).toStringAsFixed(1)}%，习惯完成 ${daily.habitChecked}/${daily.habitTotal}。',
    '重点洞察：${insight.summary} (r=${insight.coefficient.toStringAsFixed(2)})',
  ];
});

final yearlyHeatmapProvider = Provider<List<double>>((ref) {
  return List.generate(365, (index) {
    final base = (index % 7) / 6;
    final wave = ((index % 30) / 30);
    return (base * 0.6 + wave * 0.4).clamp(0.0, 1.0);
  });
});
