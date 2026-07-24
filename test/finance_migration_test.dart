import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';

void main() {
  test('fresh install creates all finance tables and CRUD works', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON'),
    ));

    // Verify all finance tables are accessible after onCreate
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );

    // PaymentAccounts
    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: 'acc-001', userId: 'user-001',
            accountName: 'Test', accountType: 'CASH',
          ),
        );
    expect((await db.select(db.paymentAccounts).get()).length, 1);

    // FinancialTransaction
    await db.into(db.financialTransaction).insert(
          FinancialTransactionCompanion.insert(
            transactionId: 'tx-001', userId: 'user-001',
            flowType: 'EXPENSE', amount: 50.0,
            categoryId: 'food', accountId: 'acc-001',
            loggedAt: DateTime.now(),
          ),
        );
    expect((await db.select(db.financialTransaction).get()).length, 1);

    // AssetInventory
    await db.into(db.assetInventory).insert(
          AssetInventoryCompanion.insert(
            assetId: 'asset-001', userId: 'user-001',
            assetName: 'MacBook', purchasePrice: 9999.0,
            purchaseDate: DateTime.now(), iconId: 'laptop',
          ),
        );
    expect((await db.select(db.assetInventory).get()).length, 1);

    // ExpenseCategories
    await db.into(db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            categoryId: 'cat-001', userId: 'user-001',
            categoryName: '三餐', categoryIcon: '🍱',
          ),
        );
    expect((await db.select(db.expenseCategories).get()).length, 1);

    // BudgetSettings
    await db.into(db.budgetSettings).insert(
          BudgetSettingsCompanion.insert(
            budgetId: 'budget-001', userId: 'user-001',
            categoryId: 'total', monthKey: '2026-05', budgetAmount: 5000.0,
          ),
        );
    expect((await db.select(db.budgetSettings).get()).length, 1);

    // AssetValueSnapshots
    await db.into(db.assetValueSnapshots).insert(
          AssetValueSnapshotsCompanion.insert(
            snapshotId: 'snap-001', userId: 'user-001',
            snapshotDate: DateTime.now(),
          ),
        );
    expect((await db.select(db.assetValueSnapshots).get()).length, 1);

    await db.close();
  });
}
