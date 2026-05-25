/// Daily Amortized Cost (ADC) calculator.
/// ADC = purchasePrice / ((today - purchaseDate).inDays + 1)
class AdcCalculator {
  AdcCalculator._();

  static double calculate({
    required double purchasePrice,
    required DateTime purchaseDate,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final daysHeld = now.difference(purchaseDate).inDays + 1;
    if (daysHeld <= 0) return purchasePrice;
    return purchasePrice / daysHeld;
  }
}
