import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/vital_calculator.dart';

// ── Enums ──

enum ActionType { feed, drink, sport, rest }

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

const metValues = <String, double>{
  '跑步': 9.8, '走路': 3.5, '骑行': 6.8, '游泳': 7.0, '力量': 5.0, '瑜伽': 3.0,
};

const defaultBodyWeight = 65.0;

double calculateCaloriesBurned(String exerciseName, int minutes) {
  final met = metValues[exerciseName] ?? 5.0;
  return met * minutes * defaultBodyWeight / 60;
}

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
    PetActionLog(logId: 'a4', actionType: ActionType.sport, valueNumeric: 30, subCategory: '走路', createdAt: _now.subtract(const Duration(hours: 4))),
  ];
}

// ── Providers ──

final actionLogNotifierProvider =
    StateNotifierProvider<ActionLogNotifier, List<PetActionLog>>((ref) {
  return ActionLogNotifier();
});

final petStatusProvider = Provider<PetStatus>((ref) {
  final logs = ref.watch(actionLogNotifierProvider);
  final vitals = VitalCalculator.calculate(
    logs.map((l) => _ActionLogAdapter(l)).toList(),
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
  double waterMl = 0, sportMin = 0, calIn = 0, calOut = 0;
  for (final log in logs) {
    switch (log.actionType) {
      case ActionType.drink:
        waterMl += log.valueNumeric;
      case ActionType.feed:
        calIn += log.valueNumeric;
      case ActionType.sport:
        sportMin += log.valueNumeric;
        calOut += calculateCaloriesBurned(log.subCategory ?? '走路', log.valueNumeric.toInt());
      case ActionType.rest:
        break;
    }
  }
  return TodaySummary(
    waterMl: waterMl,
    sportMinutes: sportMin,
    caloriesIn: calIn,
    caloriesOut: calOut,
    sleepHours: 7.5,
  );
});
