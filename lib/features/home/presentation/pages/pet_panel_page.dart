import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/pet_animation_state.dart';
import '../../domain/vital_calculator.dart';
import '../providers/home_providers.dart';
import '../widgets/pet_character.dart';

class PetPanelPage extends ConsumerWidget {
  const PetPanelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petStatus = ref.watch(petStatusProvider);
    final vitals = petStatus.vitals;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('体征仪表盘'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildPetDisplay(petStatus),
            const SizedBox(height: 16),
            _buildOverallStatus(petStatus.overallStatusLevel),
            const SizedBox(height: 16),
            _buildDimensionGrid(vitals),
            const SizedBox(height: 20),
            _buildWeeklyTrend(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPetDisplay(PetStatus petStatus) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: PetCharacter(
            animationState: PetAnimationMapper.fromVitals(petStatus.vitals),
            hydrationLevel: petStatus.hydrationPoints,
            energyLevel: petStatus.energyPoints,
            moodLevel: petStatus.moodPoints,
            bodyShapeLevel: petStatus.bodyShapePoints,
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }

  Widget _buildOverallStatus(String level) {
    final color = _levelColor(level);
    final label = _levelLabel(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(25), color.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite, color: color, size: 20),
          const SizedBox(width: 10),
          const Text('综合状态', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionGrid(PetVitals vitals) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: vitals.dimensions.map((d) => _DimensionGauge(dimension: d)).toList(),
    );
  }

  Widget _buildWeeklyTrend() {
    final trend = VitalCalculator.weeklyTrend();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7日走势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrendPainter(trend: trend),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = DateTime.now().subtract(Duration(days: 6 - i));
              return Text('${day.month}/${day.day}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)));
            }),
          ),
        ],
      ),
    );
  }

  Color _levelColor(String level) => switch (level) {
    'EXCELLENT' => ModuleColors.statusExcellent,
    'GOOD' => ModuleColors.statusNormal,
    'NORMAL' => ModuleColors.statusNormal,
    'LOW' => ModuleColors.statusTired,
    'CRITICAL' => ModuleColors.statusCritical,
    _ => ModuleColors.statusNormal,
  };

  String _levelLabel(String level) => switch (level) {
    'EXCELLENT' => '极佳',
    'GOOD' => '良好',
    'NORMAL' => '正常',
    'LOW' => '偏低',
    'CRITICAL' => '危险',
    _ => '正常',
  };
}

class _DimensionGauge extends StatelessWidget {
  const _DimensionGauge({required this.dimension});
  final DimensionStatus dimension;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dimension.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(dimension.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dimension.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(dimension.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dimension.color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: (dimension.points / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: dimension.color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${dimension.points}/100',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> trend;
  _TrendPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;
    final paint = Paint()
      ..color = ModuleColors.daily
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = ModuleColors.daily
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minVal = trend.reduce((a, b) => a < b ? a : b) - 5;
    final maxVal = trend.reduce((a, b) => a > b ? a : b) + 5;
    final range = maxVal - minVal;

    final points = <Offset>[];
    for (var i = 0; i < trend.length; i++) {
      final x = size.width * i / (trend.length - 1);
      final y = size.height - (size.height * (trend[i] - minVal) / range);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.trend != trend;
}
