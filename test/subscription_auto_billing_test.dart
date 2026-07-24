// hide isNull:drift 与 flutter_test 都导出 isNull,本文件用 matcher 版本。
import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/core/event_bus/bus.dart';
import 'package:life_os/core/event_bus/events.dart';
import 'package:life_os/core/workers/midnight_settlement_service.dart';
import 'package:life_os/features/finance/data/repositories/finance_repository_drift.dart';

/// 订阅到期自动入账（P1-4）集成测 —— 在 NativeDatabase.memory() 上验证
/// MidnightSettlementService.postDueSubscriptionBillings：
///   ① 到期 post 一笔 AMORTIZED 交易（区间=计费周期实际天数、sourceSubscriptionId 回填）+ 扣余额；
///   ② 推进 nextBillingDate；
///   ③ 幂等：同订阅同周期不重复入账、不重复扣款；
///   ④ 落后多周期逐周期补账；
///   ⑤ isActive=false 不入账。
void main() {
  late AppDatabase db;
  late FinanceRepositoryDrift repo;
  late MidnightSettlementService service;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    repo = FinanceRepositoryDrift(db);
    // 交易 categoryId FK 引用 expense_categories;预置默认分类(含 'subscription')。
    await repo.ensureCategoriesSeeded();
    service = MidnightSettlementService(db);
  });

  tearDown(() async => db.close());

  /// 建一个账户 + 一个到期订阅。后续按需从 repo 单查取 id。
  Future<void> seedDueSubscription({
    required double amount,
    required String billingCycle,
    required DateTime nextBillingDate,
    double accountBalance = 1000,
    String serviceName = '流媒体',
  }) async {
    await repo.addAccount('卡', 'CASH', false, accountBalance);
    final accountId = (await repo.getAccounts()).single.accountId;
    await repo.addSubscription(
      serviceName: serviceName,
      amount: amount,
      billingCycle: billingCycle,
      nextBillingDate: nextBillingDate,
      accountId: accountId,
    );
  }

  Future<String> singleAccountId() async =>
      (await repo.getAccounts()).single.accountId;

  Future<String> singleSubscriptionId() async =>
      (await repo.getSubscriptions()).single.subscriptionId;

  group('P1-4 订阅到期自动入账', () {
    test('到期 post 一笔 AMORTIZED 交易 + 扣余额 + 推进 nextBillingDate', () async {
      await seedDueSubscription(
        amount: 30,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 7, 1),
        accountBalance: 1000,
      );
      final target = DateTime(2026, 7, 24);

      final posted = await service.postDueSubscriptionBillings(target);

      expect(posted, 1);

      // 余额按全额扣(1000 - 30 = 970)。
      expect((await repo.getAccounts()).single.balance, 970);

      // 一笔 AMORTIZED 交易,区间=本计费周期(2026-07-01..2026-07-31,31 天)。
      final tx = (await repo.getTransactions()).single;
      expect(tx.expenseNature, 'AMORTIZED');
      expect(tx.amount, 30);
      expect(tx.categoryId, 'subscription');
      expect(tx.sourceSubscriptionId, await singleSubscriptionId());
      expect(tx.amortizeStartDate, DateTime(2026, 7, 1));
      expect(tx.amortizeEndDate, DateTime(2026, 7, 31));
      final coverageDays =
          tx.amortizeEndDate!.difference(tx.amortizeStartDate!).inDays + 1;
      expect(coverageDays, 31); // 区间 = 计费周期实际天数

      // nextBillingDate 推进到下个周期(2026-08-01)。
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2026, 8, 1),
      );
    });

    test('幂等:重复执行不重复入账、不重复扣款', () async {
      await seedDueSubscription(
        amount: 30,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 7, 1),
        accountBalance: 1000,
      );
      final target = DateTime(2026, 7, 24);

      await service.postDueSubscriptionBillings(target);
      // 再跑一次:nextBillingDate 已推进到 2026-08-01 > target,本周期不再到期。
      final posted2 = await service.postDueSubscriptionBillings(target);

      expect(posted2, 0);
      // 仍只有一笔交易、余额只扣一次(970)。
      expect(await repo.getTransactions(), hasLength(1));
      expect((await repo.getAccounts()).single.balance, 970);
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2026, 8, 1),
      );
    });

    test('部分失败恢复:同周期已入账则跳过(不重复扣款)但仍推进 nextBillingDate',
        () async {
      // 模拟「上次插了交易但没推进 nextBillingDate」的部分失败:按相同幂等键
      // (sourceSubscriptionId + amortizeStartDate)预置一笔交易,但余额未扣、
      // nextBillingDate 未推进。
      await seedDueSubscription(
        amount: 30,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 7, 1),
        accountBalance: 1000,
      );
      final accountId = await singleAccountId();
      final subId = await singleSubscriptionId();
      final target = DateTime(2026, 7, 24);
      await db.into(db.financialTransaction).insert(
            FinancialTransactionCompanion.insert(
              transactionId: 'pre-existing-tx-id',
              userId: 'user-001',
              flowType: 'EXPENSE',
              amount: 30,
              categoryId: 'subscription',
              accountId: accountId,
              loggedAt: target,
              expenseNature: const Value('AMORTIZED'),
              amortizeStartDate: Value(DateTime(2026, 7, 1)),
              amortizeEndDate: Value(DateTime(2026, 7, 31)),
              sourceSubscriptionId: Value(subId),
            ),
          );

      final posted = await service.postDueSubscriptionBillings(target);

      // 已存在 → 跳过入账(不重复扣款),但推进了 nextBillingDate。
      expect(posted, 0);
      expect((await repo.getAccounts()).single.balance, 1000); // 未再扣
      expect(await repo.getTransactions(), hasLength(1)); // 仍是预置那一笔
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2026, 8, 1),
      );
    });

    test('区间 = 计费周期实际天数(QUARTERLY,90 天)', () async {
      await seedDueSubscription(
        amount: 90,
        billingCycle: 'QUARTERLY',
        nextBillingDate: DateTime(2026, 1, 1),
      );
      // target 在季中(2026-02-15):本季已到期,下季(04-01)未到期。
      await service.postDueSubscriptionBillings(DateTime(2026, 2, 15));

      final tx = (await repo.getTransactions()).single;
      expect(tx.amortizeStartDate, DateTime(2026, 1, 1));
      expect(tx.amortizeEndDate, DateTime(2026, 3, 31)); // 2026 非闰:31+28+31=90
      expect(tx.amortizeEndDate!.difference(tx.amortizeStartDate!).inDays + 1, 90);
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2026, 4, 1),
      );
    });

    test('区间 = 计费周期实际天数(YEARLY,365 天)', () async {
      await seedDueSubscription(
        amount: 365,
        billingCycle: 'YEARLY',
        nextBillingDate: DateTime(2026, 1, 1),
      );
      await service.postDueSubscriptionBillings(DateTime(2026, 6, 1));

      final tx = (await repo.getTransactions()).single;
      expect(tx.amortizeStartDate, DateTime(2026, 1, 1));
      expect(tx.amortizeEndDate, DateTime(2026, 12, 31)); // 2026 非闰:365
      expect(tx.amortizeEndDate!.difference(tx.amortizeStartDate!).inDays + 1, 365);
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2027, 1, 1),
      );
    });

    test('isActive=false 的订阅不入账', () async {
      await seedDueSubscription(
        amount: 30,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 7, 1),
      );
      final subId = await singleSubscriptionId();
      await repo.updateSubscription(subId, isActive: false);

      final posted = await service.postDueSubscriptionBillings(DateTime(2026, 7, 24));

      expect(posted, 0);
      expect(await repo.getTransactions(), isEmpty);
      expect((await repo.getAccounts()).single.balance, 1000); // 未扣
      // nextBillingDate 未推进。
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2026, 7, 1),
      );
    });

    test('落后多周期:逐周期补账,每周期一笔、ID 不重复', () async {
      // nextBillingDate = 2026-05-01,target = 2026-07-24 → MONTHLY 应补 3 期(5/6/7 月)。
      await seedDueSubscription(
        amount: 30,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 5, 1),
        accountBalance: 10000,
      );

      final posted = await service.postDueSubscriptionBillings(DateTime(2026, 7, 24));

      expect(posted, 3);
      final txs = await repo.getTransactions();
      expect(txs, hasLength(3));
      // 三笔分别覆盖 5/6/7 月,起点各异、ID 不重复。
      expect(
        txs.map((t) => t.amortizeStartDate).toSet(),
        {DateTime(2026, 5, 1), DateTime(2026, 6, 1), DateTime(2026, 7, 1)},
      );
      expect(txs.map((t) => t.transactionId).toSet().length, 3);
      // 余额扣 3 期(10000 - 90 = 9910)。
      expect((await repo.getAccounts()).single.balance, 9910);
      // nextBillingDate 推进到 2026-08-01(越过 target)。
      expect(
        (await repo.getSubscriptions()).single.nextBillingDate,
        DateTime(2026, 8, 1),
      );

      // 再跑一次:全部周期已入账,nextBillingDate 已越过 target → 无新增、不再扣款。
      final posted2 = await service.postDueSubscriptionBillings(DateTime(2026, 7, 24));
      expect(posted2, 0);
      expect(await repo.getTransactions(), hasLength(3));
      expect((await repo.getAccounts()).single.balance, 9910);
    });

    test('扣费时发 SubscriptionBillingEvent(§3.5 契约)', () async {
      await seedDueSubscription(
        amount: 30,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 7, 1),
      );
      final subId = await singleSubscriptionId();
      final accountId = await singleAccountId();

      // EventBus 默认异步投递,用 Completer 确定性等待。
      final completer = Completer<SubscriptionBillingEvent>();
      final subscription = globalEventBus
          .on<SubscriptionBillingEvent>()
          .listen(completer.complete);
      addTearDown(subscription.cancel);

      await service.postDueSubscriptionBillings(DateTime(2026, 7, 24));
      final event = await completer.future.timeout(const Duration(seconds: 1));

      expect(event.subscriptionId, subId);
      expect(event.amount, 30);
      expect(event.accountId, accountId);
    });
  });
}
