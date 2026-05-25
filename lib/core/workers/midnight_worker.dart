import 'package:workmanager/workmanager.dart';

import 'worker_types.dart';

/// Top-level callback dispatcher for workmanager.
/// This function must be a top-level or static function (workmanager requirement).
@pragma('vm:entry-point')
void workerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case WorkerTaskNames.midnightSettlement:
        return await _executeMidnightSettlement(inputData);
      case WorkerTaskNames.periodicHealthCheck:
        return await _executeHealthCheck();
      default:
        return false;
    }
  });
}

// workmanager callbacks run in a background isolate.
// Cross-module triggers (EventBus, Riverpod) are NOT available here.
// Settlement logic must operate directly on the database or use
// IsolateNameServer for inter-isolate signalling.

Future<bool> _executeMidnightSettlement(Map<String, dynamic>? inputData) async {
  final targetDate = inputData?['targetDate'] != null
      ? DateTime.tryParse(inputData!['targetDate'] as String)
      : DateTime.now();

  if (targetDate == null) return false;

  // TODO: 8-step settlement logic (operate on database directly)
  //   1. Todo Rollover (delay_count++, target_date = tomorrow)
  //   2. Pet Status Settlement (MA7 → body_shape ±10)
  //   3. ADC Update (recalculate daily amortized cost)
  //   4. Net Worth Snapshot → asset_value_snapshots
  //   5. Relationship Decay (warmth_score -N)
  //   6. Subscription Check → auto-write financial_transaction
  //   7. Correlation Engine (Pearson |r| ≥ 0.65 → insights)
  //   8. Daily Aggregation Cache → daily_aggregation_cache

  return true;
}

Future<bool> _executeHealthCheck() async {
  return true;
}

final _defaultConstraints = Constraints(
  networkType: NetworkType.not_required,
  requiresBatteryNotLow: false,
  requiresCharging: false,
  requiresDeviceIdle: false,
  requiresStorageNotLow: false,
);

/// Registers all background tasks with workmanager.
/// Called once from main() after WidgetsFlutterBinding.ensureInitialized().
Future<void> registerBackgroundWorkers() async {
  await Workmanager().initialize(
    workerCallbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    WorkerTaskNames.midnightSettlement,
    WorkerTaskNames.midnightSettlement,
    frequency: const Duration(hours: 24),
    constraints: _defaultConstraints,
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 10),
  );

  await Workmanager().registerPeriodicTask(
    WorkerTaskNames.periodicHealthCheck,
    WorkerTaskNames.periodicHealthCheck,
    frequency: const Duration(hours: 6),
    constraints: _defaultConstraints,
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// Cancels all registered background tasks.
Future<void> cancelAllBackgroundWorkers() async {
  await Workmanager().cancelAll();
}
