import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'pet_animation_state.dart';

// ── Enums ──

enum PetDimension { hydration, energy, bodyShape, mood }

enum VitalLevel { excellent, good, normal, low, critical }

// ── Models ──

class DimensionStatus {
  final PetDimension dimension;
  final int points;
  final VitalLevel level;

  const DimensionStatus({required this.dimension, required this.points, required this.level});

  Color get color => switch (level) {
    VitalLevel.excellent => ModuleColors.statusExcellent,
    VitalLevel.good => ModuleColors.statusNormal,
    VitalLevel.normal => ModuleColors.statusNormal,
    VitalLevel.low => ModuleColors.statusTired,
    VitalLevel.critical => ModuleColors.statusCritical,
  };

  String get label => switch (level) {
    VitalLevel.excellent => '极佳',
    VitalLevel.good => '良好',
    VitalLevel.normal => '正常',
    VitalLevel.low => '偏低',
    VitalLevel.critical => '危险',
  };

  String get name => switch (dimension) {
    PetDimension.hydration => '水分',
    PetDimension.energy => '能量',
    PetDimension.bodyShape => '体形',
    PetDimension.mood => '心情',
  };

  String get icon => switch (dimension) {
    PetDimension.hydration => '💧',
    PetDimension.energy => '⚡',
    PetDimension.bodyShape => '💪',
    PetDimension.mood => '😊',
  };
}

class PetVitals {
  final List<DimensionStatus> dimensions;
  final VitalLevel overallLevel;
  final PetAnimationState dominantAnimation;
  final PetDimension? weakestDimension;

  const PetVitals({
    required this.dimensions,
    required this.overallLevel,
    required this.dominantAnimation,
    this.weakestDimension,
  });
}

// ── Calculator ──

class VitalCalculator {
  const VitalCalculator._();

  static VitalLevel levelFromPoints(int points) {
    if (points >= 80) return VitalLevel.excellent;
    if (points >= 60) return VitalLevel.good;
    if (points >= 40) return VitalLevel.normal;
    if (points >= 20) return VitalLevel.low;
    return VitalLevel.critical;
  }

  /// 运动事件 → 宠物「能量」加分（P5-1）。向上取整，每满 10 分钟 +1 点，
  /// 不足 10 分钟也按 1 点计；非正时长不加。运动经健康 `ExerciseLog` 入账
  /// （唯一真相），宠物订阅 [ExerciseLoggedEvent] 调用此函数涨精力，不再
  /// 在宠物侧独立计消耗/写 SPORT。
  static int exerciseEnergyGain(int durationMinutes) {
    if (durationMinutes <= 0) return 0;
    return (durationMinutes / 10).ceil();
  }

  /// 计算宠物四维状态。
  ///
  /// [actionLogs] 仅含投喂/喝水/休息（P5-1 起运动不再经宠物 action log）。
  /// [exerciseEnergyBonus] 为运动事件桥累计的能量加分（默认 0）。
  static PetVitals calculate(
    List<dynamic> actionLogs, {
    int exerciseEnergyBonus = 0,
  }) {
    int hydration = 50, energy = 60, bodyShape = 0, mood = 60;

    for (final log in actionLogs) {
      final actionType = (log as dynamic).actionType;
      final value = (log as dynamic).valueNumeric as double;

      switch (actionType) {
        case 'drink':
          hydration = (hydration + (value / 50).round()).clamp(0, 100);
        case 'feed':
          energy = (energy + (value / 80).round()).clamp(0, 100);
          mood = (mood + 3).clamp(0, 100);
        case 'rest':
          mood = (mood + (value * 2).round()).clamp(0, 100);
          energy = (energy + (value * 3).round()).clamp(0, 100);
      }
    }

    // 运动能量来自事件桥（不再经 action log）。
    energy = (energy + exerciseEnergyBonus).clamp(0, 100);

    final dims = [
      DimensionStatus(dimension: PetDimension.hydration, points: hydration, level: levelFromPoints(hydration)),
      DimensionStatus(dimension: PetDimension.energy, points: energy, level: levelFromPoints(energy)),
      DimensionStatus(dimension: PetDimension.bodyShape, points: bodyShape, level: levelFromPoints(bodyShape)),
      DimensionStatus(dimension: PetDimension.mood, points: mood, level: levelFromPoints(mood)),
    ];

    final levelOrder = VitalLevel.values;
    VitalLevel overall = VitalLevel.excellent;
    PetDimension? weakest;
    int weakestIndex = levelOrder.length;

    for (final d in dims) {
      final idx = levelOrder.indexOf(d.level);
      if (idx > weakestIndex) {
        weakestIndex = idx;
        weakest = d.dimension;
      }
      if (idx > levelOrder.indexOf(overall)) {
        overall = d.level;
      }
    }

    return PetVitals(
      dimensions: dims,
      overallLevel: overall,
      dominantAnimation: _mapAnimation(weakest, overall),
      weakestDimension: weakest,
    );
  }

  static PetAnimationState _mapAnimation(PetDimension? weakest, VitalLevel overall) {
    if (overall == VitalLevel.critical) return PetAnimationState.sick;
    if (overall == VitalLevel.excellent) return PetAnimationState.excited;
    if (overall == VitalLevel.good) return PetAnimationState.happy;

    if (weakest != null && overall == VitalLevel.low) {
      return switch (weakest) {
        PetDimension.hydration => PetAnimationState.thirsty,
        PetDimension.energy => PetAnimationState.hungry,
        PetDimension.mood => PetAnimationState.tired,
        PetDimension.bodyShape => PetAnimationState.tired,
      };
    }

    return PetAnimationState.idle;
  }

  // ── 7-day trend mock data ──

  static List<double> weeklyTrend() {
    return [62, 58, 71, 65, 73, 68, 70];
  }
}
