import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/features/health/domain/nutrition.dart';

/// nutrition 换算纯函数表驱动单测（P2-3）。
///
/// 覆盖：0g / 50g / 100g / 150g（默认份量）/ 四大项分别换算、
/// 汇总累加、MealType↔dbValue 往返与未知值降级。
void main() {
  const per100 = NutritionPer100g(
    calories: 200,
    protein: 10,
    fat: 5,
    carbs: 30,
  );

  group('nutritionForGrams', () {
    test('0g 全部归零', () {
      final s = nutritionForGrams(per100: per100, grams: 0);
      expect(s.calories, 0);
      expect(s.protein, 0);
      expect(s.fat, 0);
      expect(s.carbs, 0);
    });

    test('100g 等于每100g基准', () {
      final s = nutritionForGrams(per100: per100, grams: 100);
      expect(s.calories, 200);
      expect(s.protein, 10);
      expect(s.fat, 5);
      expect(s.carbs, 30);
    });

    // 表驱动：不同克数 → calories 因子 = grams/100。
    for (final entry in <(double grams, double expectedCal)>{
      (0, 0),
      (50, 100),
      (100, 200),
      (150, 300), // 默认份量常见值
      (75, 150),
      (333, 666),
    }) {
      final grams = entry.$1;
      final expected = entry.$2;
      test('$grams g → calories=$expected', () {
        final s = nutritionForGrams(per100: per100, grams: grams);
        expect(s.calories, closeTo(expected, 1e-9));
        // 蛋白同比例：10 × grams/100。
        expect(s.protein, closeTo(10 * grams / 100, 1e-9));
      });
    }

    test('三大项同比例换算', () {
      final s = nutritionForGrams(per100: per100, grams: 250);
      expect(s.calories, 500);
      expect(s.protein, 25);
      expect(s.fat, 12.5);
      expect(s.carbs, 75);
    });

    test('基准含零值字段时换算仍正确', () {
      const water = NutritionPer100g(calories: 0, protein: 0, fat: 0, carbs: 0);
      final s = nutritionForGrams(per100: water, grams: 500);
      expect(s.calories, 0);
      expect(s.carbs, 0);
    });
  });

  group('NutritionSnapshot', () {
    test('zero + 任意值 = 该值', () {
      const s = NutritionSnapshot(calories: 50, protein: 2, fat: 1, carbs: 8);
      expect((NutritionSnapshot.zero + s).calories, 50);
    });

    test('多条记录可累加成当日合计', () {
      const a = NutritionSnapshot(calories: 100, protein: 5, fat: 2, carbs: 15);
      const b = NutritionSnapshot(calories: 250, protein: 12, fat: 6, carbs: 30);
      const c = NutritionSnapshot(calories: 80, protein: 3, fat: 4, carbs: 10);
      final sum = [a, b, c].fold(NutritionSnapshot.zero, (acc, e) => acc + e);
      expect(sum.calories, 430);
      expect(sum.protein, 20);
      expect(sum.fat, 12);
      expect(sum.carbs, 55);
    });
  });

  group('MealType', () {
    test('dbValue 为 CHECK 约束允许的四个值', () {
      expect(MealType.values.map((m) => m.dbValue).toSet(), {
        'BREAKFAST',
        'LUNCH',
        'DINNER',
        'SNACK',
      });
    });

    test('fromDbValue 往返', () {
      for (final m in MealType.values) {
        expect(MealType.fromDbValue(m.dbValue), same(m));
      }
    });

    test('未知值降级为 snack', () {
      expect(MealType.fromDbValue('UNKNOWN'), MealType.snack);
      expect(MealType.fromDbValue(''), MealType.snack);
    });
  });
}
