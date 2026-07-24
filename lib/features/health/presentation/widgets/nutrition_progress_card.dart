import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/nutrition_goal.dart';
import '../providers/goal_providers.dart';
import 'nutrition_goal_setup_sheet.dart';

const _calorieColor = Color(0xFFFF7043);
const _proteinColor = Color(0xFF42A5F5);
const _fatColor = Color(0xFFFFB300);
const _carbColor = Color(0xFF66BB6A);
const _overColor = Color(0xFFEF5350);
const _trackColor = Color(0xFFE0E0E0);

/// 每日营养总览（P2-4）：目标已设 → 热量环 + 三宏量条 + 剩余/超标；未设 →
/// 引导设置目标。
///
/// 全部读取走 `.watch()` 流派生（[nutritionProgressProvider]）：写库（记饮食 /
/// 改目标）后环与条自动刷新，无手动 invalidate。数据来源在 domain 纯函数
/// [computeNutritionProgress]，本组件只渲染。
class NutritionOverview extends ConsumerWidget {
  const NutritionOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(nutritionProgressProvider);
    if (progress == null) {
      return _SetGoalPrompt(onSetup: () => showNutritionGoalSetupSheet(context));
    }
    return _NutritionProgressCard(
      progress: progress,
      onEdit: () => showNutritionGoalSetupSheet(context),
    );
  }
}

class _NutritionProgressCard extends StatelessWidget {
  const _NutritionProgressCard({required this.progress, required this.onEdit});

  final NutritionProgress progress;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cal = progress.calorie;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CalorieRing(progress: cal),
              const SizedBox(width: 16),
              Expanded(
                child: _CalorieCaption(
                  consumed: cal.current,
                  target: cal.target,
                  exceeded: cal.exceeded,
                  remaining: cal.remaining,
                ),
              ),
              IconButton(
                tooltip: '修改目标',
                icon: const Icon(Icons.tune, size: 20, color: Color(0xFF9E9E9E)),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MacroBar(label: '蛋白质', unit: 'g', color: _proteinColor, progress: progress.protein),
          const SizedBox(height: 10),
          _MacroBar(label: '脂肪', unit: 'g', color: _fatColor, progress: progress.fat),
          const SizedBox(height: 10),
          _MacroBar(label: '碳水', unit: 'g', color: _carbColor, progress: progress.carbs),
        ],
      ),
    );
  }
}

/// 热量环形进度（fl_chart PieChart：两段 = 已摄入 / 剩余轨道，中心叠加文字）。
class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.progress});
  final MacroProgress progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              // 从顶部 12 点方向起笔。
              startDegreeOffset: 270,
              sectionsSpace: 0,
              centerSpaceRadius: 42,
              sections: _sections(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                progress.current.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: progress.exceeded ? _overColor : _calorieColor,
                ),
              ),
              const Text('kcal', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _sections() {
    // 极小值避免 0 段渲染异常（fl_chart 对 value=0 段表现不稳）。
    const eps = 1e-9;
    final fill = progress.barFill; // 0..1
    return [
      PieChartSectionData(
        value: (fill <= 0 ? eps : fill) * 100,
        color: progress.exceeded ? _overColor : _calorieColor,
        radius: 11,
        showTitle: false,
      ),
      PieChartSectionData(
        value: (fill >= 1 ? eps : 1 - fill) * 100,
        color: _trackColor,
        radius: 11,
        showTitle: false,
      ),
    ];
  }
}

class _CalorieCaption extends StatelessWidget {
  const _CalorieCaption({
    required this.consumed,
    required this.target,
    required this.exceeded,
    required this.remaining,
  });

  final double consumed;
  final double target;
  final bool exceeded;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final abs = remaining.abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('今日摄入', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (exceeded ? _overColor : _calorieColor).withAlpha(24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            exceeded
                ? '超标 ${abs.toStringAsFixed(0)} kcal'
                : '剩余 ${abs.toStringAsFixed(0)} kcal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: exceeded ? _overColor : _calorieColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '目标 ${target.toStringAsFixed(0)} kcal',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.unit,
    required this.color,
    required this.progress,
  });

  final String label;
  final String unit;
  final Color color;
  final MacroProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Text(
              '${progress.current.toStringAsFixed(1)} / ${progress.target.toStringAsFixed(0)} $unit',
              style: TextStyle(
                fontSize: 12,
                color: progress.exceeded ? _overColor : const Color(0xFF9E9E9E),
              ),
            ),
            const Spacer(),
            if (progress.target > 0)
              Text(
                progress.exceeded
                    ? '+${((progress.ratio - 1) * 100).toStringAsFixed(0)}%' // 超标百分比
                    : '${(progress.ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: progress.exceeded ? _overColor : color,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.barFill,
            minHeight: 7,
            backgroundColor: _trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.exceeded ? _overColor : color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetGoalPrompt extends StatelessWidget {
  const _SetGoalPrompt({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _calorieColor.withAlpha(20),
            _calorieColor.withAlpha(45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 22, color: _calorieColor),
              const SizedBox(width: 8),
              const Text(
                '还没有每日营养目标',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '设置目标后，这里会显示今日热量环与蛋白/脂肪/碳水进度。\n'
            '可按你的档案自动计算（TDEE），或手动填写。',
            style: TextStyle(fontSize: 12, color: Color(0xFF757575), height: 1.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onSetup,
            style: FilledButton.styleFrom(
              backgroundColor: _calorieColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('设置目标'),
          ),
        ],
      ),
    );
  }
}
