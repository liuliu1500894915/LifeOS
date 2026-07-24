import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/health/domain/met_table.dart';

/// MET 表 + 运动消耗计算单测（P3-2 验收 §4「涉及计算」）。
/// 表驱动，覆盖：MET 查表、消耗公式、缺体重降级、零值守卫、强度枚举映射。
void main() {
  group('MET 查表', () {
    test('metFor 命中预置运动的三档强度', () {
      expect(MetTable.metFor('跑步', ExerciseIntensity.low), 7.0);
      expect(MetTable.metFor('跑步', ExerciseIntensity.medium), 9.8);
      expect(MetTable.metFor('跑步', ExerciseIntensity.high), 11.5);
      expect(MetTable.metFor('走路', ExerciseIntensity.medium), 3.5);
      expect(MetTable.metFor('瑜伽', ExerciseIntensity.high), 6.0);
    });

    test('metFor 未匹配运动名回退到保守值 4.0', () {
      expect(MetTable.metFor('打高尔夫', ExerciseIntensity.medium),
          MetTable.fallbackMet);
      expect(MetTable.fallbackMet, 4.0);
    });

    test('entryFor 命中/未命中', () {
      expect(MetTable.entryFor('游泳')?.medium, 8.3);
      expect(MetTable.entryFor('不存在的运动'), isNull);
    });
  });

  group('消耗公式 (MET × 体重 × 时长h)', () {
    // 跑步 medium 9.8, 70kg, 60min → 9.8 × 70 × 1 = 686
    test('跑步中等 70kg 60min = 686 kcal', () {
      expect(
        MetTable.caloriesBurned(
            met: 9.8, weightKg: 70, durationMinutes: 60),
        closeTo(686, 1e-9),
      );
    });

    // 走路 low 2.8, 70kg, 30min → 2.8 × 70 × 0.5 = 98
    test('走路低 70kg 30min = 98 kcal', () {
      expect(
        MetTable.caloriesBurned(
            met: 2.8, weightKg: 70, durationMinutes: 30),
        closeTo(98, 1e-9),
      );
    });

    // 力量 high 8.0, 80kg, 45min → 8.0 × 80 × 0.75 = 480
    test('力量高 80kg 45min = 480 kcal', () {
      expect(
        MetTable.caloriesBurned(
            met: 8.0, weightKg: 80, durationMinutes: 45),
        closeTo(480, 1e-9),
      );
    });

    test('未知运动用 fallbackMet 估算', () {
      // 4.0 × 70 × 1 = 280
      expect(
        MetTable.caloriesBurned(
          met: MetTable.metFor('打高尔夫', ExerciseIntensity.medium),
          weightKg: 70,
          durationMinutes: 60,
        ),
        closeTo(280, 1e-9),
      );
    });
  });

  group('缺体重降级（不写死 65 当主路径）', () {
    test('weightKg ≤ 0 用 fallbackWeightKg(65) 估算', () {
      // 9.8 × 65 × 1 = 637
      expect(
        MetTable.caloriesBurned(
            met: 9.8, weightKg: 0, durationMinutes: 60),
        closeTo(9.8 * 65, 1e-9),
      );
      expect(
        MetTable.caloriesBurned(
            met: 9.8, weightKg: -5, durationMinutes: 60),
        closeTo(9.8 * 65, 1e-9),
      );
      expect(MetTable.fallbackWeightKg, 65.0);
    });

    test('usingFallbackWeight 正确标记缺体重', () {
      expect(MetTable.usingFallbackWeight(0), isTrue);
      expect(MetTable.usingFallbackWeight(-1), isTrue);
      expect(MetTable.usingFallbackWeight(65), isFalse);
      expect(MetTable.usingFallbackWeight(70), isFalse);
    });
  });

  group('零值守卫', () {
    test('时长 ≤ 0 返回 0', () {
      expect(
        MetTable.caloriesBurned(met: 9.8, weightKg: 70, durationMinutes: 0),
        0,
      );
      expect(
        MetTable.caloriesBurned(met: 9.8, weightKg: 70, durationMinutes: -10),
        0,
      );
    });

    test('MET ≤ 0 返回 0', () {
      expect(
        MetTable.caloriesBurned(met: 0, weightKg: 70, durationMinutes: 60),
        0,
      );
    });
  });

  group('ExerciseIntensity 映射', () {
    test('code 与 ExerciseLog.intensity CHECK 约束一致', () {
      expect(ExerciseIntensity.low.code, 'LOW');
      expect(ExerciseIntensity.medium.code, 'MEDIUM');
      expect(ExerciseIntensity.high.code, 'HIGH');
    });

    test('fromCode 往返（非法值回退 medium）', () {
      expect(ExerciseIntensityX.fromCode('LOW'), ExerciseIntensity.low);
      expect(ExerciseIntensityX.fromCode('HIGH'), ExerciseIntensity.high);
      expect(ExerciseIntensityX.fromCode('MEDIUM'), ExerciseIntensity.medium);
      expect(ExerciseIntensityX.fromCode(null), ExerciseIntensity.medium);
      expect(ExerciseIntensityX.fromCode('BOGUS'), ExerciseIntensity.medium);
    });
  });
}
