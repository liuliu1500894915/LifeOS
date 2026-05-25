import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/number_keyboard.dart';
import '../providers/daily_providers.dart';
import '../widgets/add_habit_drawer.dart';

class HabitDetailPage extends ConsumerWidget {
  const HabitDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(todayHabitsProvider);
    final checked = habits.where((h) => h.todayChecked).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('习惯打卡'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Column(
        children: [
          _buildSummaryBar(checked, habits.length),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HabitCard(habit: habits[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddHabitDrawer(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryBar(int checked, int total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('今日打卡', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
          const Spacer(),
          Text('$checked/$total',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ModuleColors.daily)),
          const SizedBox(width: 8),
          Text(checked == total && total > 0 ? '全部完成' : '继续加油',
              style: TextStyle(fontSize: 12, color: checked == total && total > 0 ? ModuleColors.success : const Color(0xFF9E9E9E))),
        ],
      ),
    );
  }
}

class _HabitCard extends ConsumerStatefulWidget {
  const _HabitCard({required this.habit});
  final HabitItem habit;

  @override
  ConsumerState<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<_HabitCard> with SingleTickerProviderStateMixin {
  late HabitItem _habit;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.85,
      upperBound: 1.0,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(child: _buildInfo()),
          _buildAction(),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: _habit.todayChecked
            ? ModuleColors.daily.withAlpha(20)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          _habit.habitIcon ?? '✅',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_habit.habitName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (_habit.streakDays > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 2),
                    Text('${_habit.streakDays}天',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (_habit.targetType == HabitTargetType.numeric && _habit.targetValue != null)
              Text(
                '${(_habit.todayValue ?? 0).toInt()}/${_habit.targetValue!.toInt()} ${_habit.targetUnit ?? ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
          ],
        ),
        if (_habit.targetType == HabitTargetType.numeric && _habit.targetValue != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (_habit.todayValue ?? 0) / _habit.targetValue!,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(ModuleColors.daily),
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAction() {
    if (_habit.targetType == HabitTargetType.boolean) {
      return ScaleTransition(
        scale: _scaleController,
        child: GestureDetector(
          onTap: _toggleCheckIn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _habit.todayChecked ? ModuleColors.daily : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _habit.todayChecked ? Icons.check : Icons.add,
              color: _habit.todayChecked ? Colors.white : const Color(0xFF9E9E9E),
              size: 24,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showNumericInput,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ModuleColors.daily.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('录入', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ModuleColors.daily)),
      ),
    );
  }

  void _toggleCheckIn() {
    HapticFeedback.mediumImpact();
    ref.read(habitNotifierProvider.notifier).checkHabit(_habit.habitId);
    _scaleController.reverse(from: 1.0).then((_) {
      if (!mounted) return;
      _scaleController.forward();
    });
  }

  void _showNumericInput() {
    String amount = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text(_habit.habitName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('$amount ${_habit.targetUnit ?? ''}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ModuleColors.daily)),
                        ],
                      ),
                    ),
                    NumberKeyboard(
                      showDecimal: true,
                      onKeyPressed: (key) {
                        setSheetState(() {
                          if (amount.length >= 8) return;
                          if (key == '.' && amount.contains('.')) return;
                          if (amount == '0' && key != '.') amount = '';
                          amount += key;
                        });
                      },
                      onBackspace: () {
                        setSheetState(() {
                          if (amount.isNotEmpty) amount = amount.substring(0, amount.length - 1);
                        });
                      },
                      onConfirm: () {
                        final val = double.tryParse(amount);
                        if (val != null) {
                          ref.read(habitNotifierProvider.notifier).updateValue(_habit.habitId, val);
                        }
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
