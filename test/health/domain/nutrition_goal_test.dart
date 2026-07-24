import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/features/health/domain/nutrition.dart';
import 'package:life_os/features/health/domain/nutrition_goal.dart';

/// 每日营养进度对比纯函数单测（P2-4「汇总测」）。
///
/// 覆盖 [computeNutritionProgress] / [MacroProgress] 边界：
/// 空摄入、正好达标、超标、部分、目标为 0 的退化（不得产生 NaN/∞）。
void main() {
  const target = NutritionTargets(
    calorieTarget: 2000,
    proteinTarget: 112,
    fatTarget: 56,
    carbTarget: 250,
  );

  NutritionSnapshot snap({
    double cal = 0,
    double p = 0,
    double f = 0,
    double c = 0,
  }) =>
      NutritionSnapshot(calories: cal, protein: p, fat: f, carbs: c);

  group('MacroProgress 单项', () {
    test('未摄入：剩余=目标，不超标，ratio=0', () {
      final m = computeNutritionProgress(target, snap(cal: 0)).calorie;
      expect(m.current, 0);
      expect(m.remaining, 2000);
      expect(m.exceeded, false);
      expect(m.ratio, 0);
      expect(m.barFill, 0);
    });

    test('正好达标：剩余=0，不算超标，ratio=1', () {
      final m = computeNutritionProgress(target, snap(cal: 2000)).calorie;
      expect(m.remaining, 0);
      expect(m.exceeded, false); // 严格大于才算超标
      expect(m.ratio, 1);
      expect(m.barFill, 1);
    });

    test('超标：剩余为负，exceeded=true，barFill 钳到 1，ratio>1', () {
      final m = computeNutritionProgress(target, snap(cal: 2600)).calorie;
      expect(m.exceeded, true);
      expect(m.remaining, -600);
      expect(m.ratio, closeTo(1.3, 1e-9));
      expect(m.barFill, 1); // 进度条画满
    });

    test('部分：ratio 与 barFill 一致', () {
      final m = computeNutritionProgress(target, snap(cal: 500)).calorie;
      expect(m.ratio, closeTo(0.25, 1e-9));
      expect(m.barFill, closeTo(0.25, 1e-9));
      expect(m.remaining, 1500);
    });

    test('目标为 0（退化）：ratio=0、barFill=0，无 NaN', () {
      const m = MacroProgress(current: 80, target: 0);
      expect(m.ratio, 0);
      expect(m.barFill, 0);
      expect(m.remaining, -80);
      expect(m.exceeded, true); // current>0>target
      expect(m.ratio.isNaN, false);
    });
  });

  group('computeNutritionProgress 四项', () {
    test('四项各自按对应 target 派生', () {
      final p = computeNutritionProgress(
        target,
        snap(cal: 1000, p: 56, f: 28, c: 125),
      );
      expect(p.calorie.ratio, closeTo(0.5, 1e-9));
      expect(p.protein.ratio, closeTo(0.5, 1e-9));
      expect(p.fat.ratio, closeTo(0.5, 1e-9));
      expect(p.carbs.ratio, closeTo(0.5, 1e-9));
    });

    test('宏量各自独立判断超标（蛋白超标但热量未满）', () {
      final p = computeNutritionProgress(
        target,
        snap(cal: 1000, p: 200, f: 10, c: 50),
      );
      expect(p.protein.exceeded, true);
      expect(p.calorie.exceeded, false);
      expect(p.fat.exceeded, false);
    });

    test('零目标快照：四项 remaining 均为 0', () {
      final p = computeNutritionProgress(
        NutritionTargets.zero,
        NutritionSnapshot.zero,
      );
      expect(p.calorie.remaining, 0);
      expect(p.protein.remaining, 0);
      expect(p.fat.remaining, 0);
      expect(p.carbs.remaining, 0);
    });
  });
}
