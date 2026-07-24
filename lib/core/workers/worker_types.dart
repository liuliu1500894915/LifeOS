/// Background worker types matching the background_worker_log table.
///
/// [dbValue] 为 `background_worker_log.worker_type` 列值（大写下划线），须与
/// `system_tables.dart` 里该列的 CHECK 约束逐字一致。曾误用枚举名
/// `.name.toUpperCase()`（产出 MIDNIGHTROLLOVER）触发 CHECK 失败，导致
/// `MidnightSettlementService.run` 整事务回滚、结算不落库——故改走显式映射，
/// 不依赖枚举名拼写。
enum WorkerType {
  midnightRollover('MIDNIGHT_ROLLOVER'),
  adcUpdate('ADC_UPDATE'),
  correlationEngine('CORRELATION_ENGINE'),
  subscriptionCheck('SUBSCRIPTION_CHECK'),
  netWorthSnapshot('NET_WORTH_SNAPSHOT'),
  memorialBus('MEMORIAL_BUS'),
  relationshipDecay('RELATIONSHIP_DECAY');

  const WorkerType(this.dbValue);

  /// 写入 / 查询 `background_worker_log.worker_type` 的字符串值。
  final String dbValue;
}

/// Unique task names registered with workmanager.
class WorkerTaskNames {
  WorkerTaskNames._();

  static const midnightSettlement = 'midnight_settlement';
  static const periodicHealthCheck = 'periodic_health_check';
}
