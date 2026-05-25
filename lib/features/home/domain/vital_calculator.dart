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

  static PetVitals calculate(List<dynamic> actionLogs) {
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
        case 'sport':
          bodyShape = (bodyShape + (value / 15).round()).clamp(0, 100);
          mood = (mood + 5).clamp(0, 100);
        case 'rest':
          mood = (mood + (value * 2).round()).clamp(0, 100);
          energy = (energy + (value * 3).round()).clamp(0, 100);
      }
    }

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
