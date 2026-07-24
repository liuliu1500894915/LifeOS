import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/energy_ledger.dart';
import '../../domain/nutrition_goal.dart';
import '../providers/goal_providers.dart';
import 'nutrition_goal_setup_sheet.dart';

const _intakeColor = Color(0xFFFF7043); // 吃（与健康饮食主题一致）
const _burnedColor = Color(0xFF66BB6A); // 动（与运动主题一致）
const _netColor = Color(0xFF42A5F5); // 净
const _overColor = Color(0xFFEF5350);
const _trackColor = Color(0xFFE0E0E0);

/// 能量账本卡片（P3-3）：「吃 − 动 = 净」的能量平衡，对比**固定**目标。
///
/// 全部读取走 `.watch()` 流派生（[energyLedgerProvider]）：记饮食 / 记运动 / 改
/// 目标后卡片自动刷新，无手动 invalidate。计算在 domain 纯函数
/// [computeEnergyLedger]（消耗不加回饮食额度），本组件只渲染。
class EnergyLedgerCard extends ConsumerWidget {
  const EnergyLedgerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(energyLedgerProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, size: 18, color: _netColor),
              SizedBox(width: 6),
              Text('能量账本', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _EquationRow(ledger: ledger),
          const SizedBox(height: 14),
          if (ledger.hasTarget)
            _BudgetBar(budget: ledger.budget!)
          else
            _NoTargetPrompt(onSetup: () => showNutritionGoalSetupSheet(context)),
        ],
      ),
    );
  }
}

/// 「吃 − 动 = 净」三栏等式。
class _EquationRow extends StatelessWidget {
  const _EquationRow({required this.ledger});
  final EnergyLedger ledger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Term(label: '吃', value: ledger.intakeCalories, color: _intakeColor)),
        _Op(text: '−'),
        Expanded(child: _Term(label: '动', value: ledger.burnedCalories, color: _burnedColor)),
        _Op(text: '='),
        Expanded(child: _Term(label: '净', value: ledger.netEnergy, color: _netColor, emphasize: true)),
      ],
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.label, required this.value, required this.color, this.emphasize = false});

  final String label;
  final double value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 2),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: emphasize ? 24 : 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            children: [
              TextSpan(text: value.toStringAsFixed(0)),
              const TextSpan(
                text: ' kcal',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Op extends StatelessWidget {
  const _Op({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFFBDBDBD))),
    );
  }
}

/// 摄入 vs **固定**目标的饮食额度条（消耗不加回）。
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.budget});
  final MacroProgress budget;

  @override
  Widget build(BuildContext context) {
    final exceeded = budget.exceeded;
    final absRemaining = budget.remaining.abs();
    final color = exceeded ? _overColor : _intakeColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('目标 ${budget.target.toStringAsFixed(0)} kcal',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                exceeded
                    ? '摄入超标 ${absRemaining.toStringAsFixed(0)} kcal'
                    : '还能吃 ${absRemaining.toStringAsFixed(0)} kcal',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: budget.barFill,
            minHeight: 7,
            backgroundColor: _trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        // 明确告知：运动消耗不回填饮食额度（与多数健身 App 的「消耗换食量」相反）。
        const Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: Color(0xFFBDBDBD)),
            SizedBox(width: 4),
            Text('消耗不计入饮食额度（不回填）',
                style: TextStyle(fontSize: 11, color: Color(0xFFBDBDBD))),
          ],
        ),
      ],
    );
  }
}

class _NoTargetPrompt extends StatelessWidget {
  const _NoTargetPrompt({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '还没设每日热量目标，设置后显示饮食额度',
            style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSetup,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _intakeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('设置目标', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
