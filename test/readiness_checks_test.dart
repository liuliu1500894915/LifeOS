import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/crypto/encryption_config.dart';
import 'package:life_os/core/crypto/secure_vault_cipher.dart';
import 'package:life_os/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:life_os/features/daily/presentation/providers/daily_providers.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';
import 'package:life_os/features/home/domain/vital_calculator.dart';
import 'package:life_os/features/home/presentation/providers/home_providers.dart';
import 'package:life_os/features/profile/presentation/providers/profile_providers.dart';

void main() {
  group('offline and performance readiness', () {
    test('secure vault supports both current and legacy local payload formats', () {
      final encrypted = SecureVaultCipher.encrypt('A123456789');

      expect(SecureVaultCipher.decrypt(encrypted), 'A123456789');
      expect(SecureVaultCipher.decrypt('ENC:UD1234567'), 'UD1234567');
      expect(EncryptionConfig.pageSize, 4096);
      expect(EncryptionConfig.kdfIter, greaterThanOrEqualTo(256000));
    });

    test('core providers resolve without network or platform service dependencies', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(quadrantTodoProvider), isNotEmpty);
      expect(container.read(todayTransactionsProvider), isNotEmpty);
      expect(container.read(secureDocumentsProvider), isNotEmpty);
      expect(container.read(memorialProvider), isNotEmpty);
      expect(container.read(relationshipProvider), isNotEmpty);

      final petStatus = container.read(petStatusProvider);
      final todaySummary = container.read(todaySummaryProvider);
      final finance = container.read(financeAnalyticsProvider);
      final daily = container.read(dailyAnalyticsProvider);
      final report = container.read(weeklyReportProvider);

      expect(petStatus.dimensions, hasLength(4));
      expect(todaySummary.waterMl, greaterThan(0));
      expect(finance.expense, greaterThan(0));
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
