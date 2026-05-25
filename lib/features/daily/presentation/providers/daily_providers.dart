import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';

// ── Enums ──

enum QuadrantType { A, B, C, D }

enum HabitTargetType { boolean, numeric }

// ── Models ──

class TodoItem {
  final String todoId;
  final String title;
  final QuadrantType quadrant;
  final DateTime targetDate;
  final DateTime? reminderClock;
  final bool isCompleted;
  final int delayCount;
  final String? associatedFlagId;
  final DateTime? completedAt;

  const TodoItem({
    required this.todoId,
    required this.title,
    required this.quadrant,
    required this.targetDate,
    this.reminderClock,
    this.isCompleted = false,
    this.delayCount = 0,
    this.associatedFlagId,
    this.completedAt,
  });

  TodoItem copyWith({
    String? title, QuadrantType? quadrant, DateTime? targetDate, DateTime? reminderClock,
    bool? isCompleted, int? delayCount, String? associatedFlagId, DateTime? completedAt,
  }) {
    return TodoItem(
      todoId: todoId, title: title ?? this.title, quadrant: quadrant ?? this.quadrant,
      targetDate: targetDate ?? this.targetDate, reminderClock: reminderClock ?? this.reminderClock,
      isCompleted: isCompleted ?? this.isCompleted, delayCount: delayCount ?? this.delayCount,
      associatedFlagId: associatedFlagId ?? this.associatedFlagId, completedAt: completedAt ?? this.completedAt,
    );
  }
}

class HabitItem {
  final String habitId;
  final String habitName;
  final String? habitIcon;
  final HabitTargetType targetType;
  final double? targetValue;
  final String? targetUnit;
  final int streakDays;
  final bool todayChecked;
  final double? todayValue;

  const HabitItem({
    required this.habitId, required this.habitName, this.habitIcon, required this.targetType,
    this.targetValue, this.targetUnit, this.streakDays = 0, this.todayChecked = false, this.todayValue,
  });

  HabitItem copyWith({bool? todayChecked, double? todayValue, int? streakDays}) {
    return HabitItem(
      habitId: habitId, habitName: habitName, habitIcon: habitIcon, targetType: targetType,
      targetValue: targetValue, targetUnit: targetUnit, streakDays: streakDays ?? this.streakDays,
      todayChecked: todayChecked ?? this.todayChecked, todayValue: todayValue ?? this.todayValue,
    );
  }
}

class MilestoneItem {
  final String milestoneId;
  final String title;
  final double? targetValue;
  final bool isReached;
  final DateTime? reachedAt;

  const MilestoneItem({required this.milestoneId, required this.title, this.targetValue, this.isReached = false, this.reachedAt});

  MilestoneItem copyWith({bool? isReached, DateTime? reachedAt}) {
    return MilestoneItem(milestoneId: milestoneId, title: title, targetValue: targetValue,
        isReached: isReached ?? this.isReached, reachedAt: reachedAt ?? this.reachedAt);
  }
}

class FlagItem {
  final String flagId;
  final String title;
  final String? description;
  final double targetValue;
  final double currentValue;
  final String? unit;
  final DateTime? deadline;
  final bool isCompleted;
  final List<MilestoneItem> milestones;

  const FlagItem({
    required this.flagId, required this.title, this.description, required this.targetValue,
    this.currentValue = 0, this.unit, this.deadline, this.isCompleted = false, this.milestones = const [],
  });

  FlagItem copyWith({double? currentValue, bool? isCompleted, List<MilestoneItem>? milestones}) {
    return FlagItem(flagId: flagId, title: title, description: description, targetValue: targetValue,
        currentValue: currentValue ?? this.currentValue, unit: unit, deadline: deadline,
        isCompleted: isCompleted ?? this.isCompleted, milestones: milestones ?? this.milestones);
  }
}

// ── Quadrant helpers ──

extension QuadrantTypeUI on QuadrantType {
  String get label => const {QuadrantType.A: '重要·紧急', QuadrantType.B: '重要·不紧急', QuadrantType.C: '紧急·不重要', QuadrantType.D: '不紧急·不重要'}[this]!;
  String get shortLabel => const {QuadrantType.A: 'A', QuadrantType.B: 'B', QuadrantType.C: 'C', QuadrantType.D: 'D'}[this]!;
  Color get color => const {QuadrantType.A: ModuleColors.quadrantA, QuadrantType.B: ModuleColors.quadrantB, QuadrantType.C: ModuleColors.quadrantC, QuadrantType.D: ModuleColors.quadrantD}[this]!;
}

// ── StateNotifiers ──

class TodoNotifier extends StateNotifier<List<TodoItem>> {
  TodoNotifier() : super(_mockTodos);

  void addTodo(TodoItem todo) => state = [...state, todo];

  void toggleComplete(String id) {
    state = [
      for (final t in state)
        if (t.todoId == id) t.copyWith(isCompleted: !t.isCompleted, completedAt: !t.isCompleted ? DateTime.now() : null) else t,
    ];
  }

  void moveQuadrant(String id, QuadrantType target) {
    state = [
      for (final t in state)
        if (t.todoId == id) t.copyWith(quadrant: target) else t,
    ];
  }

  static final _now = DateTime.now();
  static DateTime _dayAt(int d, [int h = 9, int m = 0]) => _now.add(Duration(days: d)).copyWith(hour: h, minute: m);

  static final _mockTodos = [
    TodoItem(todoId: 't1', title: '完成周报提交', quadrant: QuadrantType.A, targetDate: _dayAt(0), delayCount: 1),
    TodoItem(todoId: 't2', title: '修复线上紧急Bug', quadrant: QuadrantType.A, targetDate: _dayAt(0, 14), reminderClock: _dayAt(0, 13, 50)),
    TodoItem(todoId: 't3', title: '阅读系统设计文档', quadrant: QuadrantType.B, targetDate: _dayAt(1), delayCount: 2),
    TodoItem(todoId: 't4', title: '整理技术分享PPT', quadrant: QuadrantType.B, targetDate: _dayAt(2)),
    TodoItem(todoId: 't5', title: '回复团队消息', quadrant: QuadrantType.C, targetDate: _dayAt(0, 11)),
    TodoItem(todoId: 't6', title: '预约牙科检查', quadrant: QuadrantType.C, targetDate: _dayAt(3)),
    TodoItem(todoId: 't7', title: '整理书桌', quadrant: QuadrantType.D, targetDate: _dayAt(5)),
    TodoItem(todoId: 't8', title: '尝试新菜谱', quadrant: QuadrantType.D, targetDate: _dayAt(7)),
    TodoItem(todoId: 't9', title: '完成需求评审', quadrant: QuadrantType.A, targetDate: _dayAt(0, 16), isCompleted: true, completedAt: _dayAt(0, 15, 30)),
  ];
}

class HabitNotifier extends StateNotifier<List<HabitItem>> {
  HabitNotifier() : super(_mockHabits);

  void checkHabit(String id) {
    state = [
      for (final h in state)
        if (h.habitId == id)
          h.copyWith(todayChecked: !h.todayChecked, streakDays: !h.todayChecked ? h.streakDays + 1 : h.streakDays - 1)
        else h,
    ];
  }

  void updateValue(String id, double value) {
    state = [
      for (final h in state)
        if (h.habitId == id)
          h.copyWith(todayValue: value, todayChecked: value >= (h.targetValue ?? double.infinity))
        else h,
    ];
  }

  static final _mockHabits = [
    HabitItem(habitId: 'h1', habitName: '每日饮水', habitIcon: '💧', targetType: HabitTargetType.numeric, targetValue: 2000, targetUnit: 'ml', streakDays: 12, todayChecked: true, todayValue: 1200),
    HabitItem(habitId: 'h2', habitName: '冥想10分钟', habitIcon: '🧘', targetType: HabitTargetType.boolean, streakDays: 5, todayChecked: false),
    HabitItem(habitId: 'h3', habitName: '阅读30分钟', habitIcon: '📖', targetType: HabitTargetType.boolean, streakDays: 8, todayChecked: true),
    HabitItem(habitId: 'h4', habitName: '步数达标', habitIcon: '🚶', targetType: HabitTargetType.numeric, targetValue: 8000, targetUnit: '步', streakDays: 3, todayChecked: false, todayValue: 3200),
  ];
}

class FlagNotifier extends StateNotifier<List<FlagItem>> {
  FlagNotifier() : super(_mockFlags);

  void toggleMilestone(String flagId, String milestoneId) {
    state = [
      for (final f in state)
        if (f.flagId == flagId)
          f.copyWith(milestones: [
            for (final m in f.milestones)
              if (m.milestoneId == milestoneId)
                m.copyWith(isReached: !m.isReached, reachedAt: !m.isReached ? DateTime.now() : null)
              else m,
          ])
        else f,
    ];
  }

  static final _mockFlags = [
    FlagItem(
      flagId: 'f1', title: '2026年存下5万元', targetValue: 50000, currentValue: 32000, unit: '元', deadline: DateTime(2026, 12, 31),
      milestones: [
        MilestoneItem(milestoneId: 'm1', title: '存款突破2万', targetValue: 20000, isReached: true, reachedAt: DateTime(2026, 3, 15)),
        MilestoneItem(milestoneId: 'm2', title: '存款突破3.5万', targetValue: 35000),
        MilestoneItem(milestoneId: 'm3', title: '达成5万目标', targetValue: 50000),
      ],
    ),
    FlagItem(
      flagId: 'f2', title: '体重降到70kg', targetValue: 70, currentValue: 73.5, unit: 'kg', deadline: DateTime(2026, 9, 1),
      milestones: [
        MilestoneItem(milestoneId: 'm4', title: '体重降到75kg', targetValue: 75, isReached: true, reachedAt: DateTime(2026, 2, 20)),
        MilestoneItem(milestoneId: 'm5', title: '体重降到72kg', targetValue: 72),
      ],
    ),
  ];
}

// ── Providers ──

final todoNotifierProvider = StateNotifierProvider<TodoNotifier, List<TodoItem>>((ref) => TodoNotifier());

final quadrantTodoProvider = Provider<List<TodoItem>>((ref) => ref.watch(todoNotifierProvider));

final inboxTodoProvider = Provider<List<TodoItem>>((ref) {
  return ref.watch(quadrantTodoProvider).where((t) => t.quadrant == QuadrantType.D && !t.isCompleted).toList();
});

final habitNotifierProvider = StateNotifierProvider<HabitNotifier, List<HabitItem>>((ref) => HabitNotifier());

final todayHabitsProvider = Provider<List<HabitItem>>((ref) => ref.watch(habitNotifierProvider));

final flagNotifierProvider = StateNotifierProvider<FlagNotifier, List<FlagItem>>((ref) => FlagNotifier());

final flagListProvider = Provider<List<FlagItem>>((ref) => ref.watch(flagNotifierProvider));
