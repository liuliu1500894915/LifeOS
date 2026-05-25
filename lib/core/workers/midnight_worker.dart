import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import 'midnight_settlement_service.dart';
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

  final db = AppDatabase();
  final service = MidnightSettlementService(db);

  try {
    if (await service.hasRunForDate(targetDate)) {
      return true;
    }
    await service.run(targetDate);
    return true;
  } catch (_) {
    return false;
  } finally {
    await db.close();
  }
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
