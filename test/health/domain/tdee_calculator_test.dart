import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/health/domain/tdee_calculator.dart';

/// 表驱动单测，覆盖开发执行计划 §3.4 / P2-2 验收：
/// 男女 OTHER 公式、活动系数、目标系数、缺字段降级、碳水钳制、年龄边界。
void main() {
  // 固定基准日，让年龄可复现。birthDate=1995-01-01 在 ref 当天已过生日 → age=30。
  final birth = DateTime(1995, 1, 1);
  final ref = DateTime(2025, 1, 2);
  const age = 30;

  group('BMR（Mifflin-St Jeor）', () {
    // bmrBase = 10×70 + 6.25×175 − 5×30 = 1643.75
    const bmrBase = 1643.75;

    test('男：bmrBase + 5', () {
      final r = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;
      expect(r.bmr, closeTo(bmrBase + 5, 1e-9));
    });

    test('女：bmrBase − 161', () {
      final r = TdeeCalculator.calculate(
        gender: Gender.female,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;
      expect(r.bmr, closeTo(bmrBase - 161, 1e-9));
    });

    test('OTHER：男女均值（常数项 −78）', () {
      final male = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;
      final female = TdeeCalculator.calculate(
        gender: Gender.female,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;
      final other = TdeeCalculator.calculate(
        gender: Gender.other,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;
      expect(other.bmr, closeTo((male.bmr + female.bmr) / 2, 1e-9));
      expect(other.bmr, closeTo(bmrBase - 78, 1e-9));
    });
  });

  group('活动系数（TDEE = BMR × factor）', () {
    // 男 175/70/age30 → BMR 1648.75
    const bmr = 1648.75;
    final cases = <(ActivityLevel, double)>[
      (ActivityLevel.sedentary, 1.2),
      (ActivityLevel.light, 1.375),
      (ActivityLevel.moderate, 1.55),
      (ActivityLevel.active, 1.725),
      (ActivityLevel.veryActive, 1.9),
    ];
    for (final (level, factor) in cases) {
      test('${level.name} × $factor', () {
        final r = TdeeCalculator.calculate(
          gender: Gender.male,
          heightCm: 175,
          weightKg: 70,
          birthDate: birth,
          activityLevel: level,
          goalType: GoalType.maintain,
          referenceDate: ref,
        )!;
        expect(r.tdee, closeTo(bmr * factor, 1e-9));
        // maintain 下热量目标 == TDEE，顺带校验 goal 通道未串扰。
        expect(r.calorieTarget, closeTo(bmr * factor, 1e-9));
      });
    }
  });

  group('目标系数（calorieTarget = TDEE × factor）', () {
    // 男 175/70/age30/moderate → TDEE 2555.5625
    const tdee = 2555.5625;
    final cases = <(GoalType, double)>[
      (GoalType.cut, 0.8),
      (GoalType.maintain, 1.0),
      (GoalType.bulk, 1.1),
    ];
    for (final (goal, factor) in cases) {
      test('${goal.name} × $factor', () {
        final r = TdeeCalculator.calculate(
          gender: Gender.male,
          heightCm: 175,
          weightKg: 70,
          birthDate: birth,
          activityLevel: ActivityLevel.moderate,
          goalType: goal,
          referenceDate: ref,
        )!;
        expect(r.calorieTarget, closeTo(tdee * factor, 1e-9));
      });
    }
  });

  group('三大营养素分配', () {
    // 男 175/70/age30/moderate/maintain：热量目标 2555.5625
    test('蛋白 = 体重×1.6，脂肪 = 热量×25%/9，碳水 = 剩余/4', () {
      final r = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;

      expect(r.proteinTarget, closeTo(70 * 1.6, 1e-9));
      expect(r.fatTarget, closeTo(r.calorieTarget * 0.25 / 9, 1e-9));
      expect(
        r.carbTarget,
        closeTo(
          (r.calorieTarget - r.proteinTarget * 4 - r.fatTarget * 9) / 4,
          1e-9,
        ),
      );
    });

    test('三宏量热量和 ≈ 热量目标（自洽）', () {
      final r = TdeeCalculator.calculate(
        gender: Gender.female,
        heightCm: 160,
        weightKg: 55,
        birthDate: birth,
        activityLevel: ActivityLevel.light,
        goalType: GoalType.cut,
        referenceDate: ref,
      )!;
      final sumKcal = r.proteinTarget * 4 + r.fatTarget * 9 + r.carbTarget * 4;
      expect(sumKcal, closeTo(r.calorieTarget, 1e-6));
    });
  });

  group('缺字段安全降级', () {
    final base = <String, Object?>{
      'gender': Gender.male,
      'heightCm': 175.0,
      'weightKg': 70.0,
      'birthDate': birth,
    };

    test('gender 缺失 → null', () {
      final r = TdeeCalculator.calculate(
        gender: null,
        heightCm: base['heightCm']! as double,
        weightKg: base['weightKg']! as double,
        birthDate: base['birthDate']! as DateTime,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      );
      expect(r, isNull);
    });

    test('heightCm 缺失 → null', () {
      expect(
        TdeeCalculator.calculate(
          gender: Gender.male,
          heightCm: null,
          weightKg: 70,
          birthDate: birth,
          activityLevel: ActivityLevel.moderate,
          goalType: GoalType.maintain,
          referenceDate: ref,
        ),
        isNull,
      );
    });

    test('weightKg 缺失 → null', () {
      expect(
        TdeeCalculator.calculate(
          gender: Gender.male,
          heightCm: 175,
          weightKg: null,
          birthDate: birth,
          activityLevel: ActivityLevel.moderate,
          goalType: GoalType.maintain,
          referenceDate: ref,
        ),
        isNull,
      );
    });

    test('birthDate 缺失 → null', () {
      expect(
        TdeeCalculator.calculate(
          gender: Gender.male,
          heightCm: 175,
          weightKg: 70,
          birthDate: null,
          activityLevel: ActivityLevel.moderate,
          goalType: GoalType.maintain,
          referenceDate: ref,
        ),
        isNull,
      );
    });
  });

  group('missingFields', () {
    test('全缺 → 四项', () {
      expect(TdeeCalculator.missingFields(), ['性别', '身高', '体重', '出生日期']);
    });

    test('只缺身高 → [身高]', () {
      expect(
        TdeeCalculator.missingFields(
          gender: Gender.male,
          weightKg: 70,
          birthDate: birth,
        ),
        ['身高'],
      );
    });

    test('齐全 → 空', () {
      expect(
        TdeeCalculator.missingFields(
          gender: Gender.female,
          heightCm: 160,
          weightKg: 55,
          birthDate: birth,
        ),
        isEmpty,
      );
    });
  });

  group('年龄计算（ageInYears）', () {
    final birthday = DateTime(1995, 6, 15);

    test('生日前一天 → 少一岁', () {
      expect(
        TdeeCalculator.ageInYears(birthday, DateTime(2025, 6, 14)),
        29,
      );
    });

    test('生日当天 → 已满岁', () {
      expect(
        TdeeCalculator.ageInYears(birthday, DateTime(2025, 6, 15)),
        30,
      );
    });

    test('生日后一天 → 已满岁', () {
      expect(
        TdeeCalculator.ageInYears(birthday, DateTime(2025, 6, 16)),
        30,
      );
    });

    test('驱动 calculate：不同基准日 age 不同则 BMR 不同', () {
      // 生日未到（age 29）比 生日已到（age 30）的 BMR 高 5（−5×age 少减一年）。
      final beforeBirthday = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birthday,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: DateTime(2025, 6, 14),
      )!;
      final afterBirthday = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birthday,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: DateTime(2025, 6, 15),
      )!;
      expect(
        beforeBirthday.bmr - afterBirthday.bmr,
        closeTo(5, 1e-9),
      );
    });
  });

  group('碳水钳制 ≥ 0（极端值不产生负碳水）', () {
    test('蛋白+脂肪热量反超热量目标 → carb 钳制为 0', () {
      // 构造非真实边界以触发负碳水分支：高龄 + 矮身高压低 BMR（从而压低
      // 热量目标），女生 −161 进一步压低；与此同时蛋白×4 + 脂肪×9 反超
      // 热量目标，使碳水按公式为负 → 钳制为 0。
      //   bmr=414 tdee=496.8 calorieTarget=397.44
      //   蛋白×4=320 脂肪×9≈99.36 合计 419.36 > 397.44 → 原始碳水≈−5.48
      final r = TdeeCalculator.calculate(
        gender: Gender.female,
        heightCm: 100,
        weightKg: 50,
        birthDate: DateTime(1915, 1, 1),
        activityLevel: ActivityLevel.sedentary,
        goalType: GoalType.cut,
        referenceDate: DateTime(2025, 1, 2), // age = 110
      )!;
      expect(r.carbTarget, 0.0);
      // 其余目标仍为正、可返回。
      expect(r.calorieTarget, greaterThan(0));
      expect(r.proteinTarget, greaterThan(0));
    });
  });

  group('referenceDate 可注入（结果可复现）', () {
    test('同输入同基准日 → 完全相等', () {
      final a = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      );
      final b = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      );
      expect(a!.bmr, b!.bmr);
      expect(a.calorieTarget, b.calorieTarget);
    });

    // 防止误删 age 依赖：age 从 birthDate 推导，不作为入参。
    test('age 由 birthDate 推导（age=$age on ref）', () {
      final r = TdeeCalculator.calculate(
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        birthDate: birth,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        referenceDate: ref,
      )!;
      expect(TdeeCalculator.ageInYears(birth, ref), age);
      // 反推：bmr = 10×70 + 6.25×175 − 5×age + 5
      expect(r.bmr, closeTo(700 + 1093.75 - 5 * age + 5, 1e-9));
    });
  });
}
