import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';

/// P0-4 回归测:验证 finance 读取已走 Repository 的 `.watch()` 流 ——
/// 写库后相关 Provider **无需 `ref.invalidate`** 即自动重发新值。
///
/// 前提:`addTransaction`/`deleteTransaction` 在事务内改 `payment_accounts`
/// 余额,Repository 用 `customUpdate(updates: {paymentAccounts})` 声明受影响表,
/// 故 Drift 在事务 commit 后通知 `watchAccounts()` 流重发。
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 轮询泵送事件队列,直到 [test] 为真(或耗尽轮次)—— 让 Drift 流在
  /// 事务 commit 后的异步重发有机会执行,避免写死 sleep。
  Future<void> pumpUntil(bool Function() test, {int rounds = 300}) async {
    for (var i = 0; i < rounds; i++) {
      if (test()) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('加一笔支出后,账户余额流自动重发新值(无需 invalidate)', () async {
    // 首启种子 4 个默认账户(余额均为 0)。
    final accountsBefore = await container.read(accountProvider.future);
    final account = accountsBefore.first;
    final balanceBefore = account.balance;

    // 监听账户流,捕获重发的新余额。
    double? seenBalance;
    container.listen<AsyncValue<List<PaymentAccount>>>(
      accountProvider,
      (_, next) => seenBalance = next.valueOrNull
          ?.firstWhere((a) => a.accountId == account.accountId, orElse: () => account)
          .balance,
      fireImmediately: true,
    );

    // 记一笔支出:Repository 事务(插交易 + 改余额)。
    await container.read(transactionProvider.notifier).addTransaction(
          flowType: 'EXPENSE',
          amount: 42,
          categoryId: 'food',
          accountId: account.accountId,
        );

    // 余额应被流重发,恰好少 42。
    await pumpUntil(() => seenBalance == balanceBefore - 42);
    expect(seenBalance, balanceBefore - 42);
  });

  test('交易流自动重发:新增后 transactionProvider 含新记录', () async {
    await container.read(accountProvider.future);
    final accountId = container.read(accountProvider).requireValue.first.accountId;
    // 预热交易流到空列表,使监听的 fireImmediately 捕到确定初值 0。
    await container.read(transactionProvider.future);

    int? seenCount;
    container.listen<AsyncValue<List<FinancialTransactionData>>>(
      transactionProvider,
      (_, next) => seenCount = next.valueOrNull?.length,
      fireImmediately: true,
    );
    expect(seenCount, 0);

    await container.read(transactionProvider.notifier).addTransaction(
          flowType: 'EXPENSE',
          amount: 10,
          categoryId: 'food',
          accountId: accountId,
        );

    await pumpUntil(() => seenCount == 1);
    expect(seenCount, 1);
  });

  test('删交易后余额回滚,流自动反映', () async {
    await container.read(accountProvider.future);
    final account = container.read(accountProvider).requireValue.first;
    final accountId = account.accountId;
    final balanceBefore = account.balance;

    await container.read(transactionProvider.notifier).addTransaction(
          flowType: 'EXPENSE',
          amount: 25,
          categoryId: 'food',
          accountId: accountId,
        );
    await pumpUntil(
      () => container.read(accountProvider).valueOrNull?.firstWhere(
                (a) => a.accountId == accountId,
                orElse: () => account,
              ).balance ==
          balanceBefore - 25,
    );

    final txId = container.read(transactionProvider).requireValue.single.transactionId;

    await container.read(transactionProvider.notifier).deleteTransaction(txId);
    await pumpUntil(
      () => container.read(accountProvider).valueOrNull?.firstWhere(
                (a) => a.accountId == accountId,
                orElse: () => account,
              ).balance ==
          balanceBefore,
    );

    final afterBalance = container
        .read(accountProvider)
        .valueOrNull!
        .firstWhere((a) => a.accountId == accountId, orElse: () => account)
        .balance;
    expect(afterBalance, balanceBefore);
  });
}
