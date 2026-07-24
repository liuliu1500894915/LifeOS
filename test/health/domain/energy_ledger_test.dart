import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/features/health/domain/energy_ledger.dart';

/// 能量账本纯函数单测（P3-3「净值计算测」）。
///
/// 覆盖 [computeEnergyLedger] / [EnergyLedger] 边界：
/// 净值 = 摄入 − 消耗、消耗不加回额度（变消耗时 budget 不变）、无目标降级、
/// 摄入超标、零/极端值不产生 NaN。
void main() {
  EnergyLedger ledger({
    required double intake,
    required double burned,
    double? target,
  }) =>
      computeEnergyLedger(
        intakeCalories: intake,
        burnedCalories: burned,
        calorieTarget: target,
      );

  group('netEnergy 净值 = 吃 − 动', () {
    test('正值：摄入 > 消耗 → 净盈余', () {
      final l = ledger(intake: 1500, burned: 500, target: 2000);
      expect(l.netEnergy, 1000);
    });

    test('零消耗：净 = 摄入', () {
      final l = ledger(intake: 1800, burned: 0, target: 2000);
      expect(l.netEnergy, 1800);
    });

    test('负值：消耗 > 摄入 → 净赤字', () {
      final l = ledger(intake: 500, burned: 800, target: 2000);
      expect(l.netEnergy, -300);
    });

    test('双零：摄入与消耗皆 0 → 净 0', () {
      final l = ledger(intake: 0, burned: 0, target: 2000);
      expect(l.netEnergy, 0);
    });
  });

  group('消耗不加回额度（目标固定不被消耗抬高）', () {
    // 同样摄入与目标、仅消耗不同：净值随消耗变化，但饮食额度（剩余/超标/比例）
    // 必须完全一致 —— 证明消耗没有回填进额度。
    final resting = ledger(intake: 1500, burned: 0, target: 2000);
    final active = ledger(intake: 1500, burned: 500, target: 2000);

    test('消耗降低净值（向赤字移动）', () {
      expect(active.netEnergy, lessThan(resting.netEnergy));
      expect(resting.netEnergy, 1500);
      expect(active.netEnergy, 1000);
    });

    test('消耗不改变剩余额度', () {
      expect(active.budget!.remaining, resting.budget!.remaining);
      expect(active.budget!.remaining, 500);
    });

    test('消耗不改变摄入对目标的进度比例', () {
      expect(active.budget!.ratio, resting.budget!.ratio);
    });

    test('消耗不改变是否超标判定', () {
      expect(active.budget!.exceeded, resting.budget!.exceeded);
      expect(active.budget!.exceeded, false);
    });

    test('消耗不抬高目标本身（目标恒为设定值，绝不做 target + burned）', () {
      expect(active.budget!.target, 2000);
      expect(resting.budget!.target, 2000);
    });
  });

  group('饮食额度 budget（摄入 vs 固定目标）', () {
    test('未摄入：剩余 = 目标，不超标', () {
      final l = ledger(intake: 0, burned: 0, target: 2000);
      expect(l.hasTarget, true);
      expect(l.budget!.remaining, 2000);
      expect(l.budget!.exceeded, false);
    });

    test('正好达标：剩余 = 0，不算超标', () {
      final l = ledger(intake: 2000, burned: 300, target: 2000);
      expect(l.budget!.remaining, 0);
      expect(l.budget!.exceeded, false); // 严格大于才算超标
    });

    test('摄入超标：剩余为负，exceeded = true', () {
      final l = ledger(intake: 2600, burned: 400, target: 2000);
      expect(l.budget!.exceeded, true);
      expect(l.budget!.remaining, -600);
    });
  });

  group('无目标降级', () {
    test('target 为 null：hasTarget=false，budget=null，仍可算净值', () {
      final l = ledger(intake: 1500, burned: 500); // target 省略
      expect(l.hasTarget, false);
      expect(l.budget, isNull);
      expect(l.netEnergy, 1000);
    });

    test('target = 0（退化）：视为未设目标，budget=null', () {
      final l = ledger(intake: 1500, burned: 500, target: 0);
      expect(l.hasTarget, false);
      expect(l.budget, isNull);
    });

    test('target 为负（异常输入）：同样视为未设目标，不产生 NaN', () {
      final l = ledger(intake: 1500, burned: 500, target: -100);
      expect(l.hasTarget, false);
      expect(l.budget, isNull);
      expect(l.netEnergy.isNaN, false);
    });
  });

  group('极端值不产生 NaN/∞', () {
    test('极大摄入', () {
      final l = ledger(intake: 1e9, burned: 1e6, target: 2000);
      expect(l.netEnergy.isFinite, true);
      expect(l.budget!.exceeded, true);
    });

    test('小数摄入与消耗', () {
      final l = ledger(intake: 123.7, burned: 45.2, target: 2000);
      expect(l.netEnergy, closeTo(78.5, 1e-9));
      expect(l.budget!.ratio, closeTo(123.7 / 2000, 1e-9));
    });
  });
}
