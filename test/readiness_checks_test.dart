import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/crypto/encryption_config.dart';
import 'package:life_os/core/crypto/secure_vault_cipher.dart';
import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:life_os/features/daily/presentation/providers/daily_providers.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';
import 'package:life_os/features/home/domain/vital_calculator.dart';
import 'package:life_os/features/home/presentation/providers/home_providers.dart';

void main() {
  group('offline and performance readiness', () {
    test('secure vault supports both current and legacy local payload formats', () {
      final encrypted = SecureVaultCipher.encrypt('A123456789');

      expect(SecureVaultCipher.decrypt(encrypted), 'A123456789');
      expect(SecureVaultCipher.decrypt('ENC:UD1234567'), 'UD1234567');
      expect(SecureVaultCipher.decrypt('not-base64%%%'), 'not-base64%%%');
      expect(SecureVaultCipher.decrypt('Zm9v'), 'foo');
      expect(EncryptionConfig.pageSize, 4096);
      expect(EncryptionConfig.kdfIter, greaterThanOrEqualTo(256000));
    });

    test('core providers resolve without network or platform service dependencies', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(quadrantTodoProvider), isNotEmpty);

      // Async Drift-backed providers: wait for them to resolve
      final accounts = await container.read(accountProvider.future);
      expect(accounts, isNotEmpty);

      final txs = container.read(todayTransactionsProvider);
      expect(txs, isA<List<FinancialTransactionData>>());

      final assets = await container.read(assetProvider.future);
      expect(assets, isA<List<AssetInventoryData>>());

      final subs = await container.read(subscriptionProvider.future);
      expect(subs, isA<List<SubscriptionService>>());

      // Legacy compat providers
      expect(container.read(transactionNotifierProvider), isA<List<TransactionItem>>());
      expect(container.read(assetListProvider), isA<List<AssetItem>>());
      expect(container.read(subscriptionListProvider), isA<List<SubscriptionItem>>());

      // Cross-module derived providers still resolve
      final petStatus = container.read(petStatusProvider);
      final todaySummary = container.read(todaySummaryProvider);
      final daily = container.read(dailyAnalyticsProvider);
      final report = container.read(weeklyReportProvider);

      expect(petStatus.dimensions, hasLength(4));
      expect(todaySummary.waterMl, greaterThan(0));
      expect(daily.todoTotal, greaterThan(0));
      expect(report, hasLength(3));
    });

    test('vital calculator stays bounded and fast on large local log batches', () {
      final logs = List.generate(5000, (index) {
        switch (index % 4) {
          case 0:
            return const _FakeActionLog('drink', 350);
          case 1:
            return const _FakeActionLog('feed', 680);
          case 2:
            return const _FakeActionLog('sport', 45);
          default:
            return const _FakeActionLog('rest', 7.5);
        }
      });

      final stopwatch = Stopwatch()..start();
      final vitals = VitalCalculator.calculate(logs);
      stopwatch.stop();

      expect(vitals.dimensions, hasLength(4));
      for (final dimension in vitals.dimensions) {
        expect(dimension.points, inInclusiveRange(0, 100));
      }
      expect(VitalCalculator.weeklyTrend(), hasLength(7));
      expect(
        VitalCalculator.weeklyTrend().every((value) => value >= 0 && value <= 100),
        isTrue,
      );
      expect(stopwatch.elapsedMilliseconds, lessThan(250));
    });
  });
}

class _FakeActionLog {
  const _FakeActionLog(this.actionType, this.valueNumeric);

  final String actionType;
  final double valueNumeric;
}
