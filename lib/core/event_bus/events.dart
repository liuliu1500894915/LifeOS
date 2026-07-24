/// Cross-module event definitions for the Life OS event bus.
///
/// Events are dispatched from one module and handled by another.
/// They carry the minimum data necessary for the receiver to act.
library;

// ── Memorial → Daily + Finance ──

class MemorialTodoEvent {
  const MemorialTodoEvent({
    required this.memorialId,
    required this.title,
    required this.targetDate,
  });

  final String memorialId;
  final String title;
  final DateTime targetDate;
}

class MemorialBudgetLockEvent {
  const MemorialBudgetLockEvent({
    required this.memorialId,
    required this.lockAmount,
    required this.monthKey,
  });

  final String memorialId;
  final double lockAmount;
  final String monthKey;
}

// ── Document expiry → Daily ──

class DocumentExpiryEvent {
  const DocumentExpiryEvent({
    required this.docId,
    required this.docType,
    required this.expiryDate,
  });

  final String docId;
  final String docType;
  final DateTime expiryDate;
}

// ── Finance → Pet ──

class BudgetExceededEvent {
  const BudgetExceededEvent({
    required this.categoryId,
    required this.budgetAmount,
    required this.actualAmount,
  });

  final String categoryId;
  final double budgetAmount;
  final double actualAmount;
}

// ── Daily settlement worker → all modules ──

class MidnightSettlementEvent {
  const MidnightSettlementEvent({required this.targetDate});
  final DateTime targetDate;
}

// ── Subscription billing → Finance ──

class SubscriptionBillingEvent {
  const SubscriptionBillingEvent({
    required this.subscriptionId,
    required this.amount,
    required this.accountId,
  });

  final String subscriptionId;
  final double amount;
  final String accountId;
}

// ── Pet action → cross-module (home quick actions affecting finance) ──

class SugaryDrinkRecordedEvent {
  const SugaryDrinkRecordedEvent({
    required this.calories,
    required this.volumeMl,
    required this.cost,
  });

  final double calories;
  final double volumeMl;
  final double cost;
}

// ── Health → Pet ──

/// 运动（消耗）记录写入健康 `ExerciseLog`（运动唯一真相）后触发。
/// 宠物订阅此事件涨精力（P5-1）：运动不再在宠物侧独立计消耗/写 SPORT，
/// 统一经此事件驱动宠物状态。
class ExerciseLoggedEvent {
  const ExerciseLoggedEvent({
    required this.exerciseName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.loggedAt,
  });

  final String exerciseName;
  final int durationMinutes;
  final double caloriesBurned;
  final DateTime loggedAt;
}

// ── Relationship warmth decay → Daily ──

class RelationshipCrisisEvent {
  const RelationshipCrisisEvent({
    required this.contactId,
    required this.contactName,
    required this.daysSinceInteraction,
  });

  final String contactId;
  final String contactName;
  final int daysSinceInteraction;
}
