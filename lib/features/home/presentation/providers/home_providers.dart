import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/event_bus/bus.dart';
import '../../../../core/event_bus/events.dart';
import '../../domain/vital_calculator.dart';

// ── Enums ──

// P5-1：运动迁至健康 ExerciseLog（唯一真相），宠物不再记录 SPORT，
// 故枚举移除 sport，仅保留投喂/喝水/休息。
enum ActionType { feed, drink, rest }

enum DrinkType { water, beverage }

// ── Models ──

class PetActionLog {
  final String logId;
  final ActionType actionType;
  final double valueNumeric;
  final String? subCategory;
  final int subjectiveScore;
  final double associatedCost;
  final String? remark;
  final DateTime createdAt;

  const PetActionLog({
    required this.logId,
    required this.actionType,
    required this.valueNumeric,
    this.subCategory,
    this.subjectiveScore = 0,
    this.associatedCost = 0,
    this.remark,
    required this.createdAt,
  });
}

class PetStatus {
  final String petId;
  final String petName;
  final String speciesType;
  final String growthStage;
  final int hydrationPoints;
  final int bodyShapePoints;
  final int energyPoints;
  final int moodPoints;
  final String overallStatusLevel;
  final List<DimensionStatus> dimensions;
  final PetVitals vitals;

  const PetStatus({
    required this.petId,
    this.petName = '小生活',
    this.speciesType = 'CAT',
    this.growthStage = 'BABY',
    this.hydrationPoints = 100,
    this.bodyShapePoints = 0,
    this.energyPoints = 100,
    this.moodPoints = 100,
    this.overallStatusLevel = 'NORMAL',
    this.dimensions = const [],
    required this.vitals,
  });
}

class TodaySummary {
  final double waterMl;
  final double sportMinutes;
  final double caloriesIn;
  final double caloriesOut;
  final double sleepHours;

  const TodaySummary({
    this.waterMl = 0,
    this.sportMinutes = 0,
    this.caloriesIn = 0,
    this.caloriesOut = 0,
    this.sleepHours = 0,
  });
}

// ── MET lookup ──
//
// P5-1：运动消耗改由健康模块 `domain/met_table.dart` 计算（单一真相），
// 宠物侧不再维护重复的 MET 表 / 体重常量 / 消耗公式，已下线。

// ── StateNotifiers ──

class ActionLogNotifier extends StateNotifier<List<PetActionLog>> {
  ActionLogNotifier() : super(_mockLogs);

  void addAction(PetActionLog log) {
    state = [...state, log];
  }

  static final _now = DateTime.now();
  static final _mockLogs = [
    PetActionLog(logId: 'a1', actionType: ActionType.drink, valueNumeric: 500, subCategory: 'water', createdAt: _now.subtract(const Duration(hours: 3))),
    PetActionLog(logId: 'a2', actionType: ActionType.drink, valueNumeric: 350, subCategory: 'water', createdAt: _now.subtract(const Duration(hours: 1))),
    PetActionLog(logId: 'a3', actionType: ActionType.feed, valueNumeric: 650, subCategory: '午饭', createdAt: _now.subtract(const Duration(hours: 2))),
  ];
}

// ── Providers ──

final actionLogNotifierProvider =
    StateNotifierProvider<ActionLogNotifier, List<PetActionLog>>((ref) {
  return ActionLogNotifier();
});

/// 运动 → 宠物能量 事件桥（P5-1）。
///
/// 健康模块写 ExerciseLog 后发 [ExerciseLoggedEvent]（运动唯一真相在此），
/// 本 Notifier 订阅该事件，按运动时长给宠物「能量」维度加分（纯函数
/// [VitalCalculator.exerciseEnergyGain]）。宠物不再自行记录 SPORT 消耗。
///
/// 注：当前宠物状态为内存 mock（与既有 ActionLog 一致），加分累加在内存；
/// 持久化、改读 ExerciseLog 当日汇总属 P5-2。
class ExerciseEnergyBonusNotifier extends Notifier<int> {
  @override
  int build() {
    final sub = globalEventBus.on<ExerciseLoggedEvent>().listen((event) {
      state = state + VitalCalculator.exerciseEnergyGain(event.durationMinutes);
    });
    ref.onDispose(sub.cancel);
    return 0;
  }
}

final exerciseEnergyBonusProvider =
    NotifierProvider<ExerciseEnergyBonusNotifier, int>(
        ExerciseEnergyBonusNotifier.new);

final petStatusProvider = Provider<PetStatus>((ref) {
  final logs = ref.watch(actionLogNotifierProvider);
  // 订阅运动事件桥：用户在健康页记录运动 → 发事件 → 能量维度即时变化。
  final energyBonus = ref.watch(exerciseEnergyBonusProvider);
  final vitals = VitalCalculator.calculate(
    logs.map((l) => _ActionLogAdapter(l)).toList(),
    exerciseEnergyBonus: energyBonus,
  );
  final levelName = vitals.overallLevel.name.toUpperCase();
  return PetStatus(
    petId: 'pet1',
    hydrationPoints: vitals.dimensions[0].points,
    bodyShapePoints: vitals.dimensions[2].points,
    energyPoints: vitals.dimensions[1].points,
    moodPoints: vitals.dimensions[3].points,
    overallStatusLevel: levelName,
    dimensions: vitals.dimensions,
    vitals: vitals,
  );
});

class _ActionLogAdapter {
  final PetActionLog _log;
  _ActionLogAdapter(this._log);
  String get actionType => _log.actionType.name;
  double get valueNumeric => _log.valueNumeric;
  String? get subCategory => _log.subCategory;
}

final todaySummaryProvider = Provider<TodaySummary>((ref) {
  final logs = ref.watch(actionLogNotifierProvider);
  double waterMl = 0, calIn = 0;
  for (final log in logs) {
    switch (log.actionType) {
      case ActionType.drink:
        waterMl += log.valueNumeric;
      case ActionType.feed:
        calIn += log.valueNumeric;
      case ActionType.rest:
        break;
    }
  }
  // P5-1：运动消耗改由健康 ExerciseLog 记录（唯一真相），宠物 mock 不再产出
  // sportMinutes/caloriesOut。这两项汇总改读 ExerciseLog 属 P5-2，在此之前为 0。
  return TodaySummary(
    waterMl: waterMl,
    sportMinutes: 0,
    caloriesIn: calIn,
    caloriesOut: 0,
    sleepHours: 7.5,
  );
});
