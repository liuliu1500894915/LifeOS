/// Default constants used across the database schema.
class AppDefaults {
  AppDefaults._();

  // Pet
  static const int maxHydrationPoints = 100;
  static const int maxEnergyPoints = 100;
  static const int maxMoodPoints = 100;
  static const int defaultBodyShapePoints = 0;

  // Finance
  static const double defaultBalance = 0.0;
  static const double defaultReservedAmount = 0.0;

  // Profile
  static const int defaultAlertOffsetDays = 30;
  static const int defaultAdvanceDaysTodo = 7;
  static const int defaultGiftBudgetLockDays = 15;
  static const int defaultCrisisThresholdDays = 14;
  static const int defaultWarmthScore = 100;
}
