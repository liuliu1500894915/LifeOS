import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/finance_providers.dart';

class MonthlySpendingPage extends ConsumerStatefulWidget {
  const MonthlySpendingPage({super.key});

  @override
  ConsumerState<MonthlySpendingPage> createState() => _MonthlySpendingPageState();
}

class _MonthlySpendingPageState extends ConsumerState<MonthlySpendingPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final monthExpense = ref.watch(monthExpenseProvider);
    final monthBudget = ref.watch(monthBudgetProvider);
    final dailyExpense = ref.watch(monthDailyExpenseProvider);
    final monthTxs = ref.watch(monthTransactionsProvider);
    final budgetPerDay = monthBudget > 0 ? monthBudget / DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day : 0.0;

    final selected = _selectedDay ?? DateTime.now();
    final selectedDayTxs = monthTxs.where((t) {
      if (t.flowType != 'EXPENSE') return false;
      return t.loggedAt.year == selected.year && t.loggedAt.month == selected.month && t.loggedAt.day == selected.day;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('本月消费详情'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [
          TextButton(
            onPressed: () => _showBudgetDialog(context, monthBudget),
            child: Text(monthBudget > 0 ? '预算: ¥${monthBudget.toStringAsFixed(0)}' : '设置预算'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSummary(monthExpense, monthBudget),
          _buildLineChart(dailyExpense, budgetPerDay),
          _buildCalendar(dailyExpense),
          Expanded(
            child: selectedDayTxs.isEmpty
                ? const Center(child: Text('当日无消费', style: TextStyle(color: Color(0xFF9E9E9E))))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedDayTxs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final t = selectedDayTxs[index];
                      final cat = categoryForId(t.categoryId);
                      final accounts = ref.watch(accountProvider).valueOrNull ?? [];
                      final accountName = accounts.where((a) => a.accountId == t.accountId).firstOrNull?.accountName ?? '';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(cat.icon, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                            Text('-¥${t.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
                            const SizedBox(width: 8),
                            Text(accountName, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSummary(double monthExpense, double monthBudget) {
    final percent = monthBudget > 0 ? (monthExpense / monthBudget * 100).clamp(0, 150) : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('本月消费', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
              const SizedBox(height: 4),
              Text('¥${monthExpense.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
            ],
          ),
          const Spacer(),
          if (monthBudget > 0) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('预算使用', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                const SizedBox(height: 4),
                Text('${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: percent > 100 ? Colors.red : ModuleColors.finance,
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineChart(Map<int, double> dailyExpense, double budgetPerDay) {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final spots = <FlSpot>[];
    for (var d = 1; d <= daysInMonth; d++) {
      spots.add(FlSpot(d.toDouble(), dailyExpense[d] ?? 0));
    }
    final maxY = [...dailyExpense.values, budgetPerDay].fold<double>(0, (a, b) => a > b ? a : b) * 1.2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 160,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8, left: 8),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY > 0 ? maxY : 100,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)))))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5, getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)))))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            extraLinesData: budgetPerDay > 0
                ? ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: budgetPerDay, color: ModuleColors.warning.withAlpha(150), strokeWidth: 1, dashArray: [5, 5]),
                  ])
                : null,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: ModuleColors.finance,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: ModuleColors.finance.withAlpha(30)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(Map<int, double> dailyExpense) {
    return TableCalendar(
      firstDay: DateTime(_focusedDay.year, _focusedDay.month, 1),
      lastDay: DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
      },
      onFormatChanged: (format) => setState(() => _calendarFormat = format),
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) {
          final expense = dailyExpense[day.day];
          if (expense == null || expense == 0) return null;
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: ModuleColors.expense.withAlpha((expense > 200 ? 60 : 25).clamp(0, 255)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${day.day}', style: const TextStyle(fontSize: 14)),
            ),
          );
        },
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, double currentBudget) {
    final ctl = TextEditingController(text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置月预算'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '如：5000', suffixText: '元/月'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(ctl.text);
              if (amount != null && amount > 0) {
                final now = DateTime.now();
                final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                ref.read(budgetProvider.notifier).setBudget(monthKey, amount);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
