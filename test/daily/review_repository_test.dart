import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/daily/data/repositories/review_repository_drift.dart';
import 'package:life_os/features/daily/domain/daily_snapshot.dart';

/// ReviewRepository (Drift 实现) 集成测 —— P4-2。
///
/// 重点：upsert 插入/按日更新（同日覆盖、异日各行）、结构化三列可空 round-trip、
/// `summarySnapshotJson` 冻结（写入后即脱离源数据：再写别的日子，本行 json 不变）、
/// watchReviewByDate 流反映当前行。复盘按日唯一（复合主键 reviewDate+userId）。
void main() {
  late AppDatabase db;
  late ReviewRepositoryDrift repo;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    repo = ReviewRepositoryDrift(db);
  });

  tearDown(() async => db.close());

  DailyReviewSnapshot snapshot({
    double spot = 100,
    double amortized = 0,
    double intake = 1500,
    double burned = 300,
    int total = 3,
    int completed = 1,
  }) =>
      DailyReviewSnapshot(
        spotExpense: spot,
        amortizedExpense: amortized,
        intakeCalories: intake,
        burnedCalories: burned,
        todoTotal: total,
        todoCompleted: completed,
      );

  test('upsert 插入今日复盘，结构化三列 + 快照 round-trip', () async {
    await repo.upsertReview(
      date: DateTime(2026, 7, 24, 21, 30),
      moodTag: '😊',
      highlightText: '完成了 P4-2',
      improveText: '熬夜了',
      tomorrowPlanText: '早起跑步',
      summarySnapshotJson:
          DailyReviewSnapshot.encode(snapshot(spot: 88, intake: 1600)),
    );

    final row = await repo.watchReviewByDate(DateTime(2026, 7, 24)).first;
    expect(row, isNotNull);
    expect(row!.moodTag, '😊');
    expect(row.highlightText, '完成了 P4-2');
    expect(row.improveText, '熬夜了');
    expect(row.tomorrowPlanText, '早起跑步');

    final decoded = DailyReviewSnapshot.decode(row.summarySnapshotJson);
    expect(decoded, isNotNull);
    expect(decoded!.spotExpense, 88);
    expect(decoded.amortizedExpense, 0);
    // 真实成本 = 日常 + 摊销（三层自洽）。
    expect(decoded.trueExpense, 88);
    expect(decoded.intakeCalories, 1600);
  });

  test('结构化三列可空：传 null 存 NULL，读回 null', () async {
    await repo.upsertReview(
      date: DateTime(2026, 7, 24),
      moodTag: '😐',
      // 三列都不传（null）
      summarySnapshotJson: DailyReviewSnapshot.encode(snapshot()),
    );
    final row = await repo.watchReviewByDate(DateTime(2026, 7, 24)).first;
    expect(row!.highlightText, isNull);
    expect(row.improveText, isNull);
    expect(row.tomorrowPlanText, isNull);
  });

  test('同日再次 upsert 覆盖（仍一行），mood/文本/快照更新', () async {
    await repo.upsertReview(
      date: DateTime(2026, 7, 24),
      moodTag: '😐',
      highlightText: '旧高光',
      summarySnapshotJson: DailyReviewSnapshot.encode(snapshot(spot: 50)),
    );
    await repo.upsertReview(
      date: DateTime(2026, 7, 24, 23, 59), // 同一天，不同时刻
      moodTag: '😊',
      highlightText: '新高光',
      // 覆盖写入带摊销的三层快照：日常 120 + 摊销 80 = 真实 200。
      summarySnapshotJson:
          DailyReviewSnapshot.encode(snapshot(spot: 120, amortized: 80)),
    );

    final rows = await db.select(db.dailyReviewLog).get();
    expect(rows, hasLength(1)); // 按日唯一，未新增行

    final row = await repo.watchReviewByDate(DateTime(2026, 7, 24)).first;
    expect(row!.moodTag, '😊');
    expect(row.highlightText, '新高光');
    final decoded = DailyReviewSnapshot.decode(row.summarySnapshotJson)!;
    expect(decoded.spotExpense, 120);
    expect(decoded.amortizedExpense, 80);
    expect(decoded.trueExpense, 200);
  });

  test('快照冻结：写完 A 日复盘后，再写 B 日，A 日快照不变', () async {
    // A 日（7-24）冻结 spot=88。
    await repo.upsertReview(
      date: DateTime(2026, 7, 24),
      moodTag: '😊',
      summarySnapshotJson: DailyReviewSnapshot.encode(snapshot(spot: 88)),
    );
    // 模拟「后续数据变化」：B 日（7-25）以不同快照写入。
    await repo.upsertReview(
      date: DateTime(2026, 7, 25),
      moodTag: '😌',
      summarySnapshotJson: DailyReviewSnapshot.encode(snapshot(spot: 999)),
    );

    // A 日快照仍为冻结时的 88，不被 B 日写入影响。
    final a = await repo.watchReviewByDate(DateTime(2026, 7, 24)).first;
    expect(DailyReviewSnapshot.decode(a!.summarySnapshotJson)!.spotExpense, 88);
    // 两日各自独立成行。
    expect(await db.select(db.dailyReviewLog).get(), hasLength(2));
  });

  test('watchReviewByDate：当日无复盘时流内为 null', () async {
    final row = await repo.watchReviewByDate(DateTime(2026, 1, 1)).first;
    expect(row, isNull);
  });

  test('date 归一化：带时分秒的 date 仍命中同一天的复盘', () async {
    await repo.upsertReview(
      date: DateTime(2026, 7, 24, 8, 15),
      moodTag: '😊',
      summarySnapshotJson: DailyReviewSnapshot.encode(snapshot()),
    );
    // 用当天任意时刻查询都能命中。
    final row = await repo.watchReviewByDate(DateTime(2026, 7, 24, 22, 0)).first;
    expect(row, isNotNull);
    expect(row!.moodTag, '😊');
  });
}
