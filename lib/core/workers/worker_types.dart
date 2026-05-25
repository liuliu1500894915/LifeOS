/// Background worker types matching the background_worker_log table.
enum WorkerType {
  midnightRollover,
  adcUpdate,
  correlationEngine,
  subscriptionCheck,
  netWorthSnapshot,
  memorialBus,
  relationshipDecay,
}

/// Unique task names registered with workmanager.
class WorkerTaskNames {
  WorkerTaskNames._();

  static const midnightSettlement = 'midnight_settlement';
  static const periodicHealthCheck = 'periodic_health_check';
}
