class CorrelationPoint {
  final double x;
  final double y;

  const CorrelationPoint(this.x, this.y);
}

class CorrelationResult {
  final double coefficient;
  final String title;
  final String summary;
  final List<CorrelationPoint> points;

  const CorrelationResult({
    required this.coefficient,
    required this.title,
    required this.summary,
    required this.points,
  });
}

class CorrelationEngine {
  const CorrelationEngine._();

  static double pearson(List<CorrelationPoint> points) {
    if (points.length < 2) return 0;

    final n = points.length.toDouble();
    final sumX = points.fold<double>(0, (s, p) => s + p.x);
    final sumY = points.fold<double>(0, (s, p) => s + p.y);
    final sumXY = points.fold<double>(0, (s, p) => s + p.x * p.y);
    final sumX2 = points.fold<double>(0, (s, p) => s + p.x * p.x);
    final sumY2 = points.fold<double>(0, (s, p) => s + p.y * p.y);

    final numerator = (n * sumXY) - (sumX * sumY);
    final denominator = ((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY)).sqrt();
    if (denominator == 0) return 0;
    return numerator / denominator;
  }

  static CorrelationResult buildSleepVsImpulse() {
    const points = [
      CorrelationPoint(5.0, 68),
      CorrelationPoint(5.5, 61),
      CorrelationPoint(6.0, 57),
      CorrelationPoint(6.5, 48),
      CorrelationPoint(7.0, 36),
      CorrelationPoint(7.5, 31),
      CorrelationPoint(8.0, 25),
    ];
    final coefficient = pearson(points);
    return CorrelationResult(
      coefficient: coefficient,
      title: '睡眠时长 vs 冲动消费',
      summary: '睡眠越短，次日饮品/外卖等冲动消费越高。',
      points: points,
    );
  }
}

extension on double {
  double sqrt() => this <= 0 ? 0 : _sqrt(this);
}

double _sqrt(double value) {
  double x = value;
  double y = 1;
  const e = 0.000001;
  while (x - y > e) {
    x = (x + y) / 2;
    y = value / x;
  }
  return x;
}
